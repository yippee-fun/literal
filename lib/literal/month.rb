# frozen_string_literal: true

class Literal::Month < Literal::Object
	MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].freeze
	SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].freeze
	NON_LEAP_YEAR_DAY_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

	prop :year, Integer
	prop :month, _Integer(1..12)

	private def after_initialize
		freeze
	end

	# (year: Integer, month: Integer) -> Integer
	def self.number_of_days_in(year:, month:)
		if month == 2 && Literal::Year.leap_year?(year:)
			29
		else
			NON_LEAP_YEAR_DAY_IN_MONTH[month - 1]
		end
	end

	#: () -> Integer
	def __year__
		@year
	end

	#: () -> Integer
	def __month__
		@month
	end

	#: () -> Literal::Month
	def next_month
		if @month < 12
			self.class.new(year: @year, month: @month + 1)
		else
			self.class.new(year: @year + 1, month: 1)
		end
	end

	alias_method :succ, :next_month

	#: () -> Literal::Month
	def prev_month
		if @month > 1
			self.class.new(year: @year, month: @month - 1)
		else
			self.class.new(year: @year - 1, month: 12)
		end
	end

	#: () -> -1 | 0 | 1
	def <=>(other)
		case other
		when Literal::Month
			if @year == other.__year__
				@month <=> other.__month__
			else
				@year <=> other.__year__
			end
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::Year
	def year
		Literal::Year.new(year: @year)
	end

	#: (Integer) -> Literal::Day
	def day(day)
		Literal::Day.new(year: @year, month: @month, day:)
	end

	#: () -> String
	def name
		MONTH_NAMES[@month - 1]
	end

	#: () -> String
	def short_name
		SHORT_MONTH_NAMES[@month - 1]
	end

	#: () -> Integer
	def number_of_days
		self.class.number_of_days_in(year: @year, month: @month)
	end

	#: () -> Range[Literal::Day]
	def days
		(first_day..last_day)
	end

	#: () { (Literal::Day) -> void } -> void
	def each_day
		total = number_of_days

		day = 1
		while i <= total
			yield Literal::Day.new(year: @year, month: @month, day:)
			day += 1
		end
	end

	#: () -> Literal::Day
	def first_day
		Literal::Day.new(year: @year, month: @month, day: 1)
	end

	#: () -> Literal::Day
	def last_day
		Literal::Day.new(year: @year, month: @month, day: number_of_days)
	end

	#: () -> bool
	def january?
		1 == @month
	end

	#: () -> bool
	def february?
		2 == @month
	end

	#: () -> bool
	def march?
		3 == @month
	end

	#: () -> bool
	def april?
		4 == @month
	end

	#: () -> bool
	def may?
		5 == @month
	end

	#: () -> bool
	def june?
		6 == @month
	end

	#: () -> bool
	def july?
		7 == @month
	end

	#: () -> bool
	def august?
		8 == @month
	end

	#: () -> bool
	def september?
		9 == @month
	end

	#: () -> bool
	def october?
		10 == @month
	end

	#: () -> bool
	def november?
		11 == @month
	end

	#: () -> bool
	def december?
		12 == @month
	end
end
