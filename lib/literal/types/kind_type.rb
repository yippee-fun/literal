# frozen_string_literal: true

class Literal::Types::KindType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def ===(object)
		Literal.subtype?(object, @type)
	end

	freeze
end
