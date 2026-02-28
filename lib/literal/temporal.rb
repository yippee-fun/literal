# frozen_string_literal: true

# Internal implementation for shared date math, constants, patterns and types.
module Literal::Temporal
	extend self
	extend Literal::Types

	# Full english names for months starting from January
	MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].freeze

	# Short three-letter names for months starting from January
	SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].freeze

	# Full english names for week days, excluding the weekend
	WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].freeze

	# Short three-letter names for week days, excluding the weekend
	SHORT_WEEKDAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri"].freeze

	# Full english names for weekend days
	WEEKEND_DAY_NAMES = ["Saturday", "Sunday"].freeze

	# Short three-letter names for weekend days
	SHORT_WEEKEND_DAY_NAMES = ["Sat", "Sun"].freeze

	# Full english names for days of the week starting from Monday
	DAY_NAMES = [*WEEKDAY_NAMES, *WEEKEND_DAY_NAMES].freeze

	# Short three-letter names for days of the week starting from Monday
	SHORT_DAY_NAMES = [*SHORT_WEEKDAY_NAMES, *SHORT_WEEKEND_DAY_NAMES].freeze

	# An array of the number of days in each month on a non leap-year, starting with January in position 1
	DAYS_IN_MONTH_NON_LEAP_YEAR = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

	# An array of the number of days in each month on a leap-year, starting with January in position 1
	DAYS_IN_MONTH_ON_LEAP_YEAR = [nil, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

	# Month offsets used by the day-of-week congruence formula, starting with January in position 0
	DAY_OF_WEEK_MONTH_OFFSETS = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4].freeze

	# 24
	HOURS_IN_A_DAY = 24

	# 60
	MINUTES_IN_AN_HOUR = 60

	# 60
	SECONDS_IN_A_MINUTE = 60

	# 1,440
	MINUTES_IN_A_DAY = HOURS_IN_A_DAY * MINUTES_IN_AN_HOUR

	# 86,400
	SECONDS_IN_A_DAY = MINUTES_IN_A_DAY * SECONDS_IN_A_MINUTE

	# 1,000,000,000
	NANOSECONDS_IN_A_SECOND = 1_000_000_000

	# 12
	MONTHS_IN_YEAR = 12

	# A positive integer constrained to the most number of days possible in any month
	DayInt = _Integer(1..31)

	# A positive integer constrained to the most number of weeks possible in any year
	WeekInt = _Integer(1..53)

	# A positive integer constrained to the number of months in a year
	MonthInt = _Integer(1..12)

	# A union of all english weekday names
	EnglishWeekdayName = _Union(*WEEK_DAY_NAMES)

	# A union of short english weekday names
	ShortEnglishWeekdayName = _Union(*SHORT_WEEKDAY_NAMES)

	# A union of all english weekend day names
	EnglishWeekendDayName = _Union(*WEEKEND_DAY_NAMES)

	# A union of short english weekend day names
	ShortEnglishWeekendDayName = _Union(*SHORT_WEEKEND_DAY_NAMES)

	# A union of all english day names
	EnglishDayName = _Union(*DAY_NAMES)

	# Union of all short english day names, e.g. "Mon", "Tue", "Wed"
	ShortEnglishDayName = _Union(*SHORT_DAY_NAMES)

	# Union of all english month names, e.g. "January", "February", "March"
	EnglishMonthName = _Union(*MONTH_NAMES)

	# Union of all short english month names, e.g. "Jan", "Feb", "Mar"
	ShortEnglishMonthName = _Union(*SHORT_MONTH_NAMES)

	# Returns the number of days in the given year, accounting for leap years
	def days_in_year(year:)
		leap_year?(year:) ? 366 : 365
	end

	# Returns the number of hours in the given year, accounting for leap years
	def hours_in_year(year:)
		days_in_year(year:) * HOURS_IN_A_DAY
	end

	# Returns the number of minutes in the given year, accounting for leap years
	def minutes_in_year(year:)
		hours_in_year(year:) * MINUTES_IN_AN_HOUR
	end

	# Returns the number of seconds in the given year, accounting for leap years
	def seconds_in_year(year:)
		minutes_in_year(year:) * SECONDS_IN_A_MINUTE
	end

	# For a given year/month, returns the number of days in that month accounting for leap years
	def days_in_month(year:, month:)
		return nil unless month >= 1 && month <= 12
		return 29 if month == 2 && leap_year?(year:)

		DAYS_IN_MONTH_NON_LEAP_YEAR[month]
	end

	# Returns the number of hours in the given month, accounting for leap years
	def hours_in_month(year:, month:)
		days_in_month(year:, month:) * HOURS_IN_A_DAY
	end

	# Returns the number of minutes in the given month, accounting for leap years
	def minutes_in_month(year:, month:)
		days_in_month(year:, month:) * MINUTES_IN_A_DAY
	end

	# Returns the number of seconds in the given month, accounting for leap years
	def seconds_in_month(year:, month:)
		days_in_month(year:, month:) * SECONDS_IN_A_DAY
	end

	# Returns the number of days since the epoch (1 January1, 1970) for the given date
	def days_since_epoch(year:, month:, day:)
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

	def leap_year?(year:)
		year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
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

	# Returns the number of ISO weeks in the given year
	def iso_weeks_in_year(year:)
		jan_1 = day_of_week(year:, month: 1, day: 1)
		(jan_1 == 4 || (jan_1 == 3 && leap_year?(year:))) ? 53 : 52
	end

	# Returns true if the given year is CE (Common Era), false if BCE (Before Common Era)
	def ce?(year:)
		year > 0
	end

	# Returns true if the given year is BCE (Before Common Era), false if CE (Common Era)
	def bce?(year:)
		year < 0
	end
end
