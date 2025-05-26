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

	def as_pack
		marshal_dump
	end

	def marshal_load(payload)
		_version, value, was_frozen = payload

		@value = value
		freeze if was_frozen
	end

	def marshal_dump
		[1, @value, frozen?].freeze
	end

	freeze
end
