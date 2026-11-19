# frozen_string_literal: true

# @api private
#
# Unions, nilables, tagged unions and results: the types `Literal.subtype?`
# takes apart into their members, so comparing with one goes through it.
module Literal::Types::Distributed
	def <=(other, context: nil)
		Literal.subtype?(self, other, context:)
	end
end
