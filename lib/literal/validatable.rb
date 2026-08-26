# frozen_string_literal: true

# Included into every class that extends Literal::Properties.
module Literal::Validatable
	# The object as it stands, validated by its class's rules — for a shape
	# that may have drifted since construction. Answers a Literal::Result; the
	# receiver is never mutated, and a Success carries the object itself.
	def validate
		Literal::Validations::Validator.validate(self.class, self)
	end

	def valid?
		validate.success?
	end

	# Called from every construction path once each value is assigned and type
	# checked. A writer passes `only` and the prospective value, narrowing to
	# the stipulations its property is part of and judging the value before it
	# is stored, so a failure leaves the object untouched. Values are read
	# straight out of storage rather than through readers, which a shape need
	# not declare at all.
	private def __literal_check_rules__(only = nil, written = nil)
		errors = Literal::Validations::Collector.new
		properties = self.class.literal_properties

		Literal::Validations::Validator.run_stipulations(self.class, errors, only:) do |name|
			if name == only
				written
			else
				instance_variable_get(properties[name].__ivar__)
			end
		end

		return unless errors.any?

		Literal::ValidationError.raise_trimmed(shape: self.class, errors: errors.to_errors)
	end
end
