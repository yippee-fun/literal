# frozen_string_literal: true

# @api private
class Literal::Types::ClassType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Class(#{@type.name})"
	end

	def ===(value)
		Class === value && (value == @type || value < @type)
	end

	def >=(other)
		case other
		when Literal::Types::ClassType
			Literal.subtype?(other.type, @type)
		when Literal::Types::DescendantType
			(Class === other.type) && Literal.subtype?(other.type, @type)
		else
			false
		end
	end

	freeze
end
