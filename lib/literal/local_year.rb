# frozen_string_literal: true

class Literal::LocalYear < Literal::Data
	include Comparable

	prop :year, Integer

	#: (year: Integer) -> Integer
	def self.days_in_year(year)
		leap_year?(year) ? 366 : 365
	end

	#: (year: Integer) -> bool
	def self.leap_year?(year)
		year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
	end

	#: (Literal::LocalYear, Literal::LocalYear) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Literal::LocalYear
	def next_year
		self.class.new(year: @year + 1)
	end

	alias_method :succ, :next_year

	#: () -> Literal::LocalYear
	def prev_year
		self.class.new(year: @year - 1)
	end

	alias_method :pred, :prev_year

	#: (Literal::LocalYear) -> -1 | 0 | 1 | nil
	def <=>(other)
		case other
		when self.class
			@year <=> other.year
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::LocalMonth
	def first_month
		Literal::LocalMonth.new(year: @year, month: 1)
	end

	#: () -> Literal::LocalMonth
	def last_month
		Literal::LocalMonth.new(year: @year, month: 12)
	end

	#: () -> Literal::LocalDate
	def first_day
		Literal::LocalDate.new(year: @year, month: 1, day: 1)
	end

	#: () -> Literal::LocalDate
	def last_day
		Literal::LocalDate.new(year: @year, month: 12, day: 31)
	end

	#: () -> Range[Literal::LocalMonth]
	def months
		(first_month..last_month)
	end

	#: (Integer) -> Literal::LocalMonth
	def month(month)
		Literal::LocalMonth.new(year: @year, month:)
	end

	#: (Integer) -> Literal::YearMonth
	def year_month(month)
		Literal::YearMonth.new(year: @year, month:)
	end

	#: () { (Literal::LocalMonth) -> void } -> void
	def each_month(&)
		return enum_for(__method__) { 12 } unless block_given?

		i = 1
		while i <= 12
			yield Literal::LocalMonth.new(year: @year, month: i)
			i += 1
		end
	end

	#: () { (Literal::LocalDate) -> void } -> void
	def each_day
		return enum_for(__method__) { self.class.days_in_year(@year) } unless block_given?

		day = first_day
		last = last_day

		while day <= last
			yield day
			day = day.next_day
		end
	end

	#: () -> Literal::LocalMonth
	def january
		Literal::LocalMonth.new(year: @year, month: 1)
	end

	#: () -> Literal::LocalMonth
	def february
		Literal::LocalMonth.new(year: @year, month: 2)
	end

	#: () -> Literal::LocalMonth
	def march
		Literal::LocalMonth.new(year: @year, month: 3)
	end

	#: () -> Literal::LocalMonth
	def april
		Literal::LocalMonth.new(year: @year, month: 4)
	end

	#: () -> Literal::LocalMonth
	def may
		Literal::LocalMonth.new(year: @year, month: 5)
	end

	#: () -> Literal::LocalMonth
	def june
		Literal::LocalMonth.new(year: @year, month: 6)
	end

	#: () -> Literal::LocalMonth
	def july
		Literal::LocalMonth.new(year: @year, month: 7)
	end

	#: () -> Literal::LocalMonth
	def august
		Literal::LocalMonth.new(year: @year, month: 8)
	end

	#: () -> Literal::LocalMonth
	def september
		Literal::LocalMonth.new(year: @year, month: 9)
	end

	#: () -> Literal::LocalMonth
	def october
		Literal::LocalMonth.new(year: @year, month: 10)
	end

	#: () -> Literal::LocalMonth
	def november
		Literal::LocalMonth.new(year: @year, month: 11)
	end

	#: () -> Literal::LocalMonth
	def december
		Literal::LocalMonth.new(year: @year, month: 12)
	end

	#: () -> bool
	def leap_year?
		self.class.leap_year?(@year)
	end

	#: () -> bool
	def ce?
		@year > 0
	end

	#: () -> bool
	def bce?
		@year < 0
	end

	#: () -> String
	def iso8601
		@year.to_s
	end

	alias_method :to_s, :iso8601

	#: (?year: Integer) -> Literal::LocalYear
	def with(year: @year)
		Literal::LocalYear.new(year:)
	end

	#: (Literal::LocalYear) -> bool
	def equals(other)
		self == other
	end
end
