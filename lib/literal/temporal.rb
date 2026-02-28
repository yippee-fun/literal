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

	HOURS_IN_A_DAY = 24
	MINUTES_IN_AN_HOUR = 60
	SECONDS_IN_A_MINUTE = 60
	MINUTES_IN_A_DAY = HOURS_IN_A_DAY * MINUTES_IN_AN_HOUR
	SECONDS_IN_A_DAY = MINUTES_IN_A_DAY * SECONDS_IN_A_MINUTE

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

	def hours_in_month(year:, month:)
		days_in_month(year:, month:) * HOURS_IN_A_DAY
	end

	def minutes_in_month(year:, month:)
		hours_in_month(year:, month:) * MINUTES_IN_AN_HOUR
	end

	def seconds_in_month(year:, month:)
		minutes_in_month(year:, month:) * SECONDS_IN_A_MINUTE
	end

	def days_since_epoch(year:, month:, day:)
		civil_to_days(year, month, day)
	end

	def civil_to_days(year, month, day)
		year -= 1 if month <= 2
		era = (year >= 0) ? (year / 400) : ((year - 399) / 400)
		yoe = year - (era * 400)
		mp = month + ((month > 2) ? -3 : 9)
		doy = (((153 * mp) + 2) / 5) + day - 1
		doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy

		(era * 146_097) + doe - 719_468
	end

	# Returns an Integer between 0 and 6, where 0 is Sunday.
	def zellers_congruence(year:, month:, day:)
		if month < 3
			month += 12
			year -= 1
		end

		q = day
		m = month
		k = year % 100
		j = year / 100

		(q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
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

	# Returns ordinal day of year as 1..366
	def day_of_year(year:, month:, day:)
		day_of_year = day
		current_month = 1
		while current_month < month
			day_of_year += days_in_month(year:, month: current_month)
			current_month += 1
		end

		day_of_year
	end

	# Returns the ISO day of week as 1..7 where 1 is Monday
	def day_of_week(year:, month:, day:)
		adjusted_year = (month < 3) ? year - 1 : year
		raw = (adjusted_year + (adjusted_year / 4) - (adjusted_year / 100) + (adjusted_year / 400) + DAY_OF_WEEK_MONTH_OFFSETS[month - 1] + day) % 7
		((raw + 6) % 7) + 1
	end

	# Returns day index as 0..6 where 0 is Monday
	def day_of_week_index(year:, month:, day:)
		day_of_week(year:, month:, day:) - 1
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
