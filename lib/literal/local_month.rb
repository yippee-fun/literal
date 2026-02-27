# frozen_string_literal: true

class Literal::LocalMonth < Literal::Data
	include Comparable

	MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].freeze
	SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].freeze
	NON_LEAP_YEAR_DAY_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

	prop :year, Integer
	prop :month, _Integer(1..12)

	# (year: Integer, month: Integer) -> Integer
	def self.days_in_month(year:, month:)
		if month == 2 && Literal::LocalYear.leap_year?(year)
			29
		else
			NON_LEAP_YEAR_DAY_IN_MONTH[month - 1]
		end
	end

	#: (Literal::LocalMonth, Literal::LocalMonth) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Literal::LocalMonth
	def next_month
		if @month < 12
			self.class.new(year: @year, month: @month + 1)
		else
			self.class.new(year: @year + 1, month: 1)
		end
	end

	alias_method :succ, :next_month

	#: () -> Literal::LocalMonth
	def prev_month
		if @month > 1
			self.class.new(year: @year, month: @month - 1)
		else
			self.class.new(year: @year - 1, month: 12)
		end
	end

	alias_method :pred, :prev_month

	#: () -> -1 | 0 | 1
	def <=>(other)
		case other
		when Literal::LocalMonth
			if @year == other.year
				@month <=> other.month
			else
				@year <=> other.year
			end
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::LocalYear
	def to_year
		Literal::LocalYear.new(year: @year)
	end

	#: () -> Literal::YearMonth
	def to_year_month
		Literal::YearMonth.new(year: @year, month: @month)
	end

	#: () -> String
	def iso8601
		"#{@year}-#{format('%02d', @month)}"
	end

	alias_method :to_s, :iso8601

	#: (year: Integer, month: Integer) -> Literal::LocalMonth
	def with(year: @year, month: @month)
		Literal::LocalMonth.new(year:, month:)
	end

	#: (Literal::LocalMonth) -> bool
	def equals(other)
		self == other
	end

	#: (Integer) -> Literal::LocalDate
	def to_local_date(day)
		Literal::LocalDate.new(year: @year, month: @month, day:)
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
		self.class.days_in_month(year: @year, month: @month)
	end

	#: () -> Range[Literal::LocalDate]
	def days
		(first_day..last_day)
	end

	#: () { (Literal::LocalDate) -> void } -> void
	def each_day
		total = number_of_days
		return enum_for(__method__) { total } unless block_given?

		day = 1
		while day <= total
			yield Literal::LocalDate.new(year: @year, month: @month, day:)
			day += 1
		end
	end

	#: () -> Literal::LocalDate
	def first_day
		Literal::LocalDate.new(year: @year, month: @month, day: 1)
	end

	#: () -> Literal::LocalDate
	def last_day
		Literal::LocalDate.new(year: @year, month: @month, day: number_of_days)
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
