# frozen_string_literal: true

# Internal implementation for shared date math, constants, patterns and types.
module Literal::Temporal
	extend self
	extend Literal::Types

	# A positive integer constrained to the most number of days possible in any month
	DayInt = _Integer(1..31)

	# A positive integer constrained to the most number of weeks possible in any year
	WeekInt = _Integer(1..53)

	# A positive integer constrained to the number of months in a year
	MonthInt = _Integer(1..12)

	# Full english names for days of the week starting from Monday
	DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].freeze

	# Short three-letter names for days of the week starting from Monday
	SHORT_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].freeze

	# An array of the number of days in each month on a non leap-year, starting with January in position 0
	NON_LEAP_YEAR_DAY_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

	# Month offsets used by the day-of-week congruence formula, starting with January in position 0
	DAY_OF_WEEK_MONTH_OFFSETS = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4].freeze

	def days_in_year(year)
		leap_year?(year) ? 366 : 365
	end

	def hours_in_year(year)
		days_in_year(year) * 24
	end

	def minutes_in_year(year)
		hours_in_year(year) * 60
	end

	def seconds_in_year(year)
		minutes_in_year(year) * 60
	end

	def leap_year?(year)
		year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
	end

	# For a given year/month, returns the number of days in that month accounting for leap years
	def days_in_month(year:, month:)
		return nil unless month >= 1 && month <= 12
		return 29 if month == 2 && leap_year?(year)

		NON_LEAP_YEAR_DAY_IN_MONTH[month - 1]
	end

	# Returns the ISO day of week as 1..7 where 1 is Monday
	def day_of_week(year:, month:, day:)
		adjusted_year = (month < 3) ? year - 1 : year
		raw = (adjusted_year + (adjusted_year / 4) - (adjusted_year / 100) + (adjusted_year / 400) + DAY_OF_WEEK_MONTH_OFFSETS[month - 1] + day) % 7
		((raw + 6) % 7) + 1
	end

	def iso_weeks_in_year(year:)
		jan_1 = day_of_week(year:, month: 1, day: 1)
		(jan_1 == 4 || (jan_1 == 3 && leap_year?(year))) ? 53 : 52
	end

	def ce?(year)
		year > 0
	end

	def bce?(year)
		year < 0
	end
end
