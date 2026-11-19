# frozen_string_literal: true

class Literal::Value
	def self.to_proc
		-> (value) { new(value) }
	end

	def self.[](value)
		new(value)
	end

	def self.from_pack(payload)
		object = allocate
		object.marshal_load(payload)
		object
	end

	# Takes a list of method names and delegates them to the underlying value.
	def self.delegate(*methods)
		methods.each do |method_name|
			class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				# frozen_string_literal: true

				def #{method_name}(...)
					@value.#{method_name}(...)
				end
			RUBY
		end
	end

	def initialize(value)
		Literal.check(value, __type__)
		@value = value
		freeze
	end

	attr_reader :value

	def inspect
		"#{self.class.name}(#{value.inspect})"
	end

	def ===(other)
		self.class === other && @value == other.value
	end

	alias_method :==, :===

	def eql?(other)
		self.class == other.class && value.eql?(other.value)
	end

	def hash
		[self.class, value].hash
	end

	def as_pack
		marshal_dump
	end

	def marshal_load(payload)
		# Marshal.load rebuilds the value unfrozen, so restore its frozen state
		# before the type check, which may require it. Payloads record only
		# whether the value itself was frozen — version 1 not even that — so
		# nested values are frozen where the type requires it.
		case payload
		in [1, value, was_frozen]
			value = Literal::Freezing.restore_frozen(value, __type__)
		in [2, value, was_frozen, value_was_frozen]
			value = Literal::Freezing.restore_frozen(value, __type__)
			value.freeze if value_was_frozen
		end

		Literal.check(value, __type__)
		@value = value
		freeze if was_frozen
	end

	def marshal_dump
		[2, @value, frozen?, Literal::FROZEN.bind_call(@value)].freeze
	end

	freeze
end
