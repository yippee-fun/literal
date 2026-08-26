# frozen_string_literal: true

class Literal::Validations::Errors < Literal::Data
	prop :errors, _Array(Literal::Validations::Error)
end
