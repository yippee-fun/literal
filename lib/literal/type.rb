# frozen_string_literal: true

module Literal::Type
	def >=(other)
		self == other
	end

	def <=(other)
		case other
		when Literal::Type
			other >= self
		else
			false
		end
	end
end
