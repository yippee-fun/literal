# frozen_string_literal: true

# @api private
class Literal::Types::TupleType
	include Literal::Type

	def initialize(types)
		raise Literal::ArgumentError.new("_Tuple type must have at least one type.") if types.size < 1

		@types = types
		freeze
	end

	attr_reader :types

	def inspect
		"_Tuple(#{@types.map(&:inspect).join(', ')})"
	end

	def ===(value)
		return false unless Array === value
		types = @types
		return false unless value.size == types.size

		i, len = 0, types.size
		while i < len
			return false unless types[i] === value[i]
			i += 1
		end

		true
	end

	def record_literal_type_errors(context)
		return unless Array === context.actual

		len = [@types.size, context.actual.size].max
		i = 0
		while i < len
			actual = context.actual[i]
			if !(expected = @types[i])
				context.add_child(label: "[#{i}]", expected: Literal::Types::NeverType::Instance, actual:)
			elsif !(expected === actual)
				context.add_child(label: "[#{i}]", expected:, actual:)
			end
			i += 1
		end
	end

	def >=(other)
		case other
		when Literal::Types::TupleType
			@types == other.types
		else
			false
		end
	end

	freeze
end
