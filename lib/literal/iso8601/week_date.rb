# frozen_string_literal: true

class Literal::ISO8601::WeekDate < Literal::ISO8601::Node
	prop :year, Integer
	prop :week, Integer
	prop :weekday, Integer, default: 0

	def iso8601
		base = "#{Literal::ISO8601::Formatting.format_year(@year)}-W#{format('%02d', @week)}"
		(@weekday == 0) ? base : "#{base}-#{@weekday}"
	end

	def valid?
		weekday_omitted = @weekday == 0
		weekday_present = @weekday >= 1 && @weekday <= 7
		return false unless weekday_omitted || weekday_present

		max_weeks = Literal::Temporal.iso_weeks_in_year(year: @year)
		@week >= 1 && @week <= max_weeks
	end

	alias_method :to_s, :iso8601
end
