# frozen_string_literal: true

# @api private
class Literal::Types::SetType
	include Literal::Type

	def initialize(type)
		@type = type
		@hash = literal_hash(Literal::Types::SetType, type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::SetType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::SetType === other && Literal.member_eql?(@type, other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Set(#{@type.inspect})"
	end

	def literal_upper_bound
		Set
	end

	def ===(value)
		return false unless Set === value

		value.each do |v|
			return false unless @type === v
		end

		true
	end

	def record_literal_type_errors(context)
		return unless Set === context.actual

		context.actual.each do |actual|
			unless @type === actual
				context.add_child(label: "[]", expected: @type, actual:)
			end
		end
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::SetType
			Literal.structural_subtype?(other.type, @type, context:)
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| self.>=(constraint, context:) }
		else
			false
		end
	end

	freeze
end
