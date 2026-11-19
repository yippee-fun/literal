# frozen_string_literal: true

# @api private
class Literal::Types::MapType
	include Literal::Type

	def initialize(shape)
		@shape = shape.dup.freeze
		@hash = literal_hash(Literal::Types::MapType, @shape)
		freeze
	end

	attr_reader :shape, :hash

	def ==(other)
		Literal::Types::MapType === other && @shape == other.shape
	end

	def eql?(other)
		Literal::Types::MapType === other && @shape.eql?(other.shape)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		@shape.each_value { |type| yield type }
	end

	def inspect
		pairs = @shape.map do |key, type|
			case key
			when Symbol
				"#{label(key)}: #{type.inspect}"
			else
				"#{key.inspect} => #{type.inspect}"
			end
		end

		"_Map(#{pairs.join(', ')})"
	end

	# The key as Ruby writes a label: bare when it's an identifier, quoted
	# otherwise. Symbol#inspect escapes what the inspection's encoding can't
	# hold, so unlike the name, it can be joined with the rest.
	private def label(key)
		inspected = key.inspect.delete_prefix(":")

		case inspected
		when /\A"/, /\A[[:alpha:]_][[:alnum:]_]*[?!]?\z/
			inspected
		else
			key.name.inspect
		end
	end

	def literal_upper_bound
		Hash
	end

	def ===(other)
		return false unless Hash === other

		@shape.each do |k, v|
			return false unless v === other[k]
		end

		true
	end

	def record_literal_type_errors(context)
		unless Hash === context.actual
			return
		end

		@shape.each do |key, expected|
			unless context.actual.key?(key) || expected === nil
				context.add_child(label: "[#{key.inspect}]", expected:, actual: nil)
				next
			end

			actual = context.actual[key]
			unless expected === actual
				context.add_child(label: "[#{key.inspect}]", expected:, actual:)
			end
		end
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::MapType
			other_shape = other.shape

			# A key the other map leaves unconstrained can hold anything.
			@shape.all? do |k, v|
				Literal.structural_subtype?(other_shape.fetch(k, Literal::Types::VoidType::Instance), v, context:)
			end
		else
			false
		end
	end

	freeze
end
