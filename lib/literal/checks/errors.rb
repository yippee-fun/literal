# frozen_string_literal: true

class Literal::Checks::Errors < Literal::Data
	prop :errors, _Array(Literal::Checks::Error)

	# So that a failed check can be reported inside any Ractor.
	Literal.make_shareable(self)
end
