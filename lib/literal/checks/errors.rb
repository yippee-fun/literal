# frozen_string_literal: true

class Literal::Checks::Errors < Literal::Data
	prop :errors, _Array(Literal::Checks::Error)
end
