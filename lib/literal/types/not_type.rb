# frozen_string_literal: true

# @api private
class Literal::Types::NotType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Not(#{@type.inspect})"
	end

	def ===(value)
		!(@type === value)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::NotType
			Literal.subtype?(other.type, @type, context:)
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal.subtype?(constraint, self, context:) }
		else
			false
		end
	end

	freeze
end
