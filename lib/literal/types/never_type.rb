# frozen_string_literal: true

# @api private
class Literal::Types::NeverType
	Instance = new.freeze

	include Literal::Type

	def inspect
		"_Never"
	end

	def ===(value)
		false
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::NeverType
			true
		else
			false
		end
	end

	def <=(_other, context: nil)
		true
	end

	freeze
end
