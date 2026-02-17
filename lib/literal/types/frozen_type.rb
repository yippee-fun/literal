# frozen_string_literal: true

# @api private
class Literal::Types::FrozenType
	ALWAYS_FROZEN = Set[Symbol, Integer, Float, Numeric, true, false, nil].freeze

	include Literal::Type

	def initialize(type)
		if ALWAYS_FROZEN.include?(type)
			warn "_Frozen type is redundant for #{type.inspect} since it is always frozen."
		end

		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Frozen(#{@type.inspect})"
	end

	def ===(value)
		value.frozen? && @type === value
	end

	def >=(other)
		case other
		when Literal::Types::FrozenType
			Literal.subtype?(other.type, @type)
		when Literal::Types::ConstraintType
			type_match = false
			frozen_match = Literal.subtype?(other.property_constraints[:frozen?], true)

			other.object_constraints.each do |constraint|
				frozen_match ||= ALWAYS_FROZEN.include?(constraint)
				type_match ||= Literal.subtype?(constraint, @type)
				return true if frozen_match && type_match
			end

			false
		else
			false
		end
	end

	freeze
end
