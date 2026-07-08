# frozen_string_literal: true

# @api private
class Literal::Types::BooleanType
	Instance = new.freeze

	include Literal::Type

	def inspect
		"_Boolean"
	end

	def ===(value)
		true == value || false == value
	end

	def >=(other, context: nil)
		case other
		when true, false, Literal::Types::BooleanType
			true
		when Class
			!!(other <= TrueClass || other <= FalseClass)
		else
			false
		end
	end

	freeze
end
