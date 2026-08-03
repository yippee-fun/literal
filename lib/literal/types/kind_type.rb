# frozen_string_literal: true

class Literal::Types::KindType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Kind(#{@type.inspect})"
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def ===(object)
		Literal.subtype?(object, @type)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::KindType, Literal::Types::ClassType, Literal::Types::DescendantType
			Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
