# frozen_string_literal: true

module Literal::ISO8601::Formatting
	extend self

	def format_year(year)
		abs_year = year.abs
		if abs_year < 10_000
			sign = (year < 0) ? "-" : ""
			"#{sign}#{format('%04d', abs_year)}"
		elsif year < 0
			"-#{abs_year}"
		else
			"+#{year}"
		end
	end

	def format_fraction(fraction, fraction_digits)
		return nil if fraction_digits <= 0

		format("%0#{fraction_digits}d", fraction)
	end
end
