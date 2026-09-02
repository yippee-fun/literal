# frozen_string_literal: true

# Included into every class that extends Literal::Properties.
module Literal::Checks::Enforced
	# Called from every construction path once each value is assigned and type
	# checked. A writer passes `only` and the prospective value, narrowing to
	# the checks that read its property and judging the value before it is
	# stored, so a failure leaves the object untouched. Values are read straight
	# out of storage rather than through readers, which a shape need not declare
	# at all.
	private def __literal_run_checks__(only = nil, written = nil)
		errors = Literal::Checks::Collector.new
		properties = self.class.literal_properties

		Literal::Checks::Checker.run_checks(self.class, errors, only:) do |name|
			if name == only
				written
			else
				instance_variable_get(properties[name].__ivar__)
			end
		end

		return unless errors.any?

		Literal::CheckError.raise_trimmed(shape: self.class, errors: errors.to_errors)
	end
end
