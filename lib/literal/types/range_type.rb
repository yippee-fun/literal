# frozen_string_literal: true

# @api private
class Literal::Types::RangeType
	include Literal::Type

	def initialize(type)
		@type = type
		@hash = literal_hash(Literal::Types::RangeType, type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::RangeType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::RangeType === other && @type.eql?(other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Range(#{@type.inspect})"
	end

	def literal_upper_bound
		Range
	end

	def ===(value)
		Range === value && !!(
			(
				@type === value.begin && (nil === value.end || @type === value.end)
			) || (
				@type === value.end && nil === value.begin
			)
		)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::RangeType
			Literal.structural_subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
