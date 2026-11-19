# frozen_string_literal: true

# @api private
class Literal::Types::FrozenType
	ALWAYS_FROZEN = Set[Symbol, Integer, Float, true, false, nil].freeze

	include Literal::Type
	include Literal::Types::DraftTransparent

	# Relaxing drops the wrapper: representation doesn't bind draft state.
	def __relax__
		yield @type
	end

	def initialize(type)
		if ALWAYS_FROZEN.include?(type)
			warn "_Frozen type is redundant for #{type.inspect} since it is always frozen."
		end

		@type = type
		@hash = [Literal::Types::FrozenType, type].hash
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::FrozenType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::FrozenType === other && @type.eql?(other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Frozen(#{@type.inspect})"
	end

	def literal_upper_bound
		@type
	end

	def ===(value)
		!!(value.frozen? && @type === value)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::FrozenType
			Literal.subtype?(other.type, @type, context:)
		when Literal::Types::ConstraintType
			type_match = false
			frozen_match = Literal.subtype?(other.property_constraints[:frozen?], true, context:)

			other.object_constraints.each do |constraint|
				frozen_match ||= ALWAYS_FROZEN.include?(constraint) || Literal::Types::FrozenType === constraint
				type_match ||= Literal.subtype?(constraint, @type, context:)
				return true if frozen_match && type_match
			end

			false
		when Module
			ALWAYS_FROZEN.include?(other) && Literal.subtype?(other, @type, context:)
		else
			false
		end
	end

	Anything = new(Literal::Types::VoidType::Instance)

	freeze
end
