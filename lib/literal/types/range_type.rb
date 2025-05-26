# frozen_string_literal: true

# @api private
class Literal::Types::RangeType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

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

	def >=(other)
		case other
		when Literal::Types::RangeType
			Literal.subtype?(other.type, @type)
		else
			false
		end
	end

	freeze
end
