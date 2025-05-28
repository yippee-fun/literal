# frozen_string_literal: true

class Literal::Day < Literal::Data
	DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].freeze
	SHORT_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].freeze

	prop :year, Integer
	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)

	#: (year: Integer, month: Integer, day: Integer) -> Integer
	def self.zellers_congruence(year:, month:, day:)
		year, month, day = self.class.adjusted_date_for_zeller(year:, month:, day:)

		q = day
		m = month
		k = year % 100
		j = year / 100

		(q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
	end

	#: (year: Integer, month: Integer, day: Integer) -> [Integer, Integer, Integer]
	def self.adjusted_date_for_zeller(year:, month:, day:)
		if month < 3
			month += 12
			year -= 1
		end

		[year, month, day].freeze
	end

	private def after_initialize
		unless @day <= Literal::Month.number_of_days_in(year: @year, month: @month)
			raise ArgumentError
		end
	end

	#: () -> String
	def name
		DAY_NAMES[day_of_week_index]
	end

	#: () -> String
	def short_name
		SHORT_DAY_NAMES[day_of_week_index]
	end

	#: () -> Literal::Day
	def succ
		days_in_month = Literal::Month.number_of_days_in(year: @year, month: @month)

		if @day < days_in_month
			Literal::Day.new(year: @year, month: @month, day: @day + 1)
		elsif @month < 12
			Literal::Day.new(year: @year, month: @month + 1, day: 1)
		else
			Literal::Day.new(year: @year + 1, month: 1, day: 1)
		end
	end

	#: () -> Literal::Day
	def prev
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

	# TODO: Waiting on duration and addition
	def this_monday; end
	def this_tuesday; end
	def this_wednesday; end
	def this_thursday; end
	def this_friday; end
	def this_saturday; end
	def this_sunday; end

	def next_monday; end
	def next_tuesday; end
	def next_wednesday; end
	def next_thursday; end
	def next_friday; end
	def next_saturday; end
	def next_sunday; end

	def last_monday; end
	def last_tuesday; end
	def last_wednesday; end
	def last_thursday; end
	def last_friday; end
	def last_saturday; end
	def last_sunday; end

	# Return the day of the week as an integer from 0 to 6 but where the 0th is Monday.
	#: () -> Integer
	private def day_of_week_index
		(self.class.zellers_congruence(@year, @month, @day) + 5) % 7
	end
end
