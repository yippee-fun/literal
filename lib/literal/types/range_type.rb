# frozen_string_literal: true

# @api private
class Literal::Types::RangeType
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
		"_Range(#{@type.inspect})"
	end

	def ===(value)
		Range === value && (
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
			Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
