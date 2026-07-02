# frozen_string_literal: true

# @api private
class Literal::Types::EnumerableType
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
		"_Enumerable(#{@type.inspect})"
	end

	def ===(value)
		Enumerable === value && value.all?(@type)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::EnumerableType
			Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
