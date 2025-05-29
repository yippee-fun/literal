# frozen_string_literal: true

class Literal::Day < Literal::Data
	DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].freeze
	SHORT_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].freeze

	prop :year, Integer
	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)

	#: (year: Integer, month: Integer, day: Integer) -> Integer
	def self.zellers_congruence(year:, month:, day:)
		year, month, day = adjusted_date_for_zeller(year:, month:, day:)

		q = day
		m = month
		k = year % 100
		j = year / 100

		(q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
	end

	#: (year: Integer, month: Integer, day: Integer) -> [Integer, Integer, Integer]
	private_class_method def self.adjusted_date_for_zeller(year:, month:, day:)
		if month < 3
			month += 12
			year -= 1
		end

		[year, month, day].freeze
	end

	#: () -> void
	private def after_initialize
		unless @day <= Literal::Month.number_of_days_in(year: @year, month: @month)
			raise ArgumentError
		end

		freeze
	end

	#: () -> String
	def name
		DAY_NAMES[day_of_week_index]
	end

	#: () -> String
	def short_name
		SHORT_DAY_NAMES[day_of_week_index]
	end

	#: () -> Integer
	def day_of_year
		day_of_year = @day

		month = 1
		while month < @month
			day_of_year += Literal::Month.number_of_days_in(year: @year, month:)
			month += 1
		end

		day_of_year
	end

	#: () -> Integer
	def day_of_month
		@day
	end

	# Return the day of week from 1 to 7, starting on Monday.
	#: () -> Integer
	def day_of_week
		day_of_week_index + 1
	end

	#: () -> Literal::Day
	def next_day
		days_in_month = Literal::Month.number_of_days_in(year: @year, month: @month)

		if @day < days_in_month
			Literal::Day.new(year: @year, month: @month, day: @day + 1)
		elsif @month < 12
			Literal::Day.new(year: @year, month: @month + 1, day: 1)
		else
			Literal::Day.new(year: @year + 1, month: 1, day: 1)
		end
	end

	alias_method :succ, :next_day

	#: () -> Literal::Day
	def prev_day
		if @day > 1
			Literal::Day.new(year: @year, month: @month, day: @day - 1)
		elsif @month > 1
			Literal::Day.new(year: @year, month: @month - 1, day: Literal::Month.number_of_days_in(year: @year, month: @month - 1))
		else
			Literal::Day.new(year: @year - 1, month: 12, day: Literal::Month.number_of_days_in(year: @year - 1, month: 12))
		end
	end

	#: () -> bool
	def monday?
		0 == day_of_week_index
	end

	#: () -> bool
	def tuesday?
		1 == day_of_week_index
	end

	#: () -> bool
	def wednesday?
		2 == day_of_week_index
	end

	#: () -> bool
	def thursday?
		3 == day_of_week_index
	end

	#: () -> bool
	def friday?
		4 == day_of_week_index
	end

	#: () -> bool
	def saturday?
		5 == day_of_week_index
	end

	#: () -> bool
	def sunday?
		6 == day_of_week_index
	end

	#: () -> Literal::Month
	def month
		Literal::Month.new(year: @year, month: @month)
	end

	#: () -> Literal::Year
	def year
		Literal::Year.new(year: @year)
	end

	#: () -> bool
	def weekend?
		day_of_week_index > 4
	end

	#: () -> bool
	def weekday?
		day_of_week_index < 5
	end

	def +(other)
		case other
		when Literal::Duration
			year, month, day = @year, @month, @day

			year += other.years
			month += other.months
			day += other.days

			if month > 12
				year += (month - 1) / 12
				month = ((month - 1) % 12) + 1
			elsif month < 1
				year -= (month.abs / 12) + 1
				month = 12 - ((month.abs - 1) % 12)
			end

			# Optimisation for when adding more than 400 years worth of days.
			if day > 146_097
				years += (400 * (days / 146_097))
				days %= 146_097
			end

			if day > 0
				while day > (days_in_month = Literal::Month.number_of_days_in(year:, month:))
					month += 1
					day -= days_in_month
				end
			elsif day < 0
				while day < 0
					month -= 1
					day += Literal::Month.number_of_days_in(year:, month:)
				end
			end

			Literal::Day.new(year:, month:, day:)
		else
			raise ArgumentError
		end
	end

	def -(other)
		case other
		when Literal::Duration
			self + (-other)
		end
	end

	#: () -> Literal::Day
	def next_monday
		next_day_of_week(0)
	end

	#: () -> Literal::Day
	def next_tuesday
		next_day_of_week(1)
	end

	#: () -> Literal::Day
	def next_wednesday
		next_day_of_week(2)
	end

	#: () -> Literal::Day
	def next_thursday
		next_day_of_week(3)
	end

	#: () -> Literal::Day
	def next_friday
		next_day_of_week(4)
	end

	#: () -> Literal::Day
	def next_saturday
		next_day_of_week(5)
	end

	#: () -> Literal::Day
	def next_sunday
		next_day_of_week(6)
	end

	#: () -> Literal::Day
	def prev_monday
		prev_day_of_week(0)
	end

	#: () -> Literal::Day
	def prev_tuesday
		prev_day_of_week(1)
	end

	#: () -> Literal::Day
	def prev_wednesday
		prev_day_of_week(2)
	end

	#: () -> Literal::Day
	def prev_thursday
		prev_day_of_week(3)
	end

	#: () -> Literal::Day
	def prev_friday
		prev_day_of_week(4)
	end

	#: () -> Literal::Day
	def prev_saturday
		prev_day_of_week(5)
	end

	#: () -> Literal::Day
	def prev_sunday
		prev_day_of_week(6)
	end

	#: () { (Literal::Time) -> void } -> void
	def each_hour
		hour = 0
		while hour < 24
			yield Literal::Time.new(year: @year, month: @month, day: @day, hour: i)
			hour += 1
		end
	end

	#: () { (Literal::Time) -> void } -> void
	def each_minute
		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				yield Literal::Time.new(year: @year, month: @month, day: @day, hour:, minute:)
				minute += 1
			end
			hour += 1
		end
	end

	#: () { (Literal::Time) -> void } -> void
	def each_second
		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				second = 0
				while second < 60
					yield Literal::Time.new(year: @year, month: @month, day: @day, hour:, minute:, second:)
					second += 1
				end
				minute += 1
			end
			hour += 1
		end
	end

	# Return the day of the week as an integer from 0 to 6 but where the 0th is Monday.
	#: () -> Integer
	private def day_of_week_index
		(self.class.zellers_congruence(year: @year, month: @month, day: @day) + 5) % 7
	end

	#: (Integer) -> Literal::Day
	private def next_day_of_week(target_day_index)
		days_until_target = (target_day_index + 7 - day_of_week_index) % 7
		days_until_target = 7 if days_until_target == 0
		self + Literal::Duration.new(days: days_until_target)
	end

	#: (Integer) -> Literal::Day
	private def prev_day_of_week(target_day_index)
		days_until_target = (day_of_week_index - target_day_index) % 7
		days_until_target = 7 if days_until_target == 0
		self - Literal::Duration.new(days: days_until_target)
	end
end
