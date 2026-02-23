# frozen_string_literal: true

# @api private
class Literal::Types::FalsyType
	Instance = new.freeze

	include Literal::Type

	def initialize
		freeze
	end

	def inspect
		"_Falsy"
	end

	def ===(value)
		!value
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::FalsyType, nil, false
			true
		else
			false
		end
	end

	freeze
end
