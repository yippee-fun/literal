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

	freeze
end
