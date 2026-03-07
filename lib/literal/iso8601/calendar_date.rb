# frozen_string_literal: true

class Literal::ISO8601::CalendarDate < Literal::ISO8601::Node
	prop :year, Integer
	prop :month, Integer
	prop :day, Integer

	def iso8601
		"#{Literal::ISO8601::Formatting.format_year(@year)}-#{format('%02d', @month)}-#{format('%02d', @day)}"
	end

	def valid?
		days_in_month = Literal::Temporal.days_in_month(year: @year, month: @month)
		days_in_month && @day >= 1 && @day <= days_in_month
	end

	alias_method :to_s, :iso8601
end
