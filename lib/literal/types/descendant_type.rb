# frozen_string_literal: true

class Literal::Types::DescendantType
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
		"_Descendant(#{@type})"
	end

	def ===(value)
		Module === value && value < @type
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::DescendantType, Literal::Types::ClassType
			Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
