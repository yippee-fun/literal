# frozen_string_literal: true

module Literal::Type
	def >=(other, context: nil)
		self == other
	end

	def <=(other, context: nil)
		case other
		when Literal::Type
			other.>=(self, context:)
		else
			false
		end
	end
end
