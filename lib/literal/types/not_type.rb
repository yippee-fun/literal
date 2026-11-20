# frozen_string_literal: true

# @api private
class Literal::Types::NotType
	include Literal::Type

	def initialize(type)
		@type = Literal::Freezing.frozen_member(type)
		@hash = literal_hash(Literal::Types::NotType, @type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::NotType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::NotType === other && Literal.member_eql?(@type, other.type)
	end

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

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::NotType
			# Contravariant: _Not(A) <= _Not(B) iff B <= A. Excluding more makes you narrower.
			context.contravariant_subtype?(@type, other.type)
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal.subtype?(constraint, self, context:) }
		else
			false
		end
	end

	freeze
end
