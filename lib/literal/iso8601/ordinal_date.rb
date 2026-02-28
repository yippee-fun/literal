# frozen_string_literal: true

class Literal::ISO8601::OrdinalDate < Literal::ISO8601::Node
	prop :year, Integer
	prop :day_of_year, Integer

	def iso8601
		"#{Literal::ISO8601::Formatting.format_year(@year)}-#{format('%03d', @day_of_year)}"
	end

	def valid?
		@day_of_year >= 1 && @day_of_year <= Literal::Temporal.days_in_year(@year)
	end

	alias_method :to_s, :iso8601
end
