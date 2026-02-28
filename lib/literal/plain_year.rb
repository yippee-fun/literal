# frozen_string_literal: true

class Literal::PlainYear < Literal::Data
	include Comparable

	prop :year, Integer

	def self.days_in_year(year)
		leap_year?(year) ? 366 : 365
	end

	def self.leap_year?(year)
		year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
	end

	def next_year
		self.class.new(year: @year + 1)
	end

	alias_method :succ, :next_year

	def prev_year
		self.class.new(year: @year - 1)
	end

	alias_method :pred, :prev_year

	def <=>(other)
		case other
		when Literal::PlainYear
			@year <=> other.year
		else
			nil
		end
	end

	def first_month
		Literal::PlainYearMonth.new(year: @year, month: 1)
	end

	def last_month
		Literal::PlainYearMonth.new(year: @year, month: 12)
	end

	def first_day
		Literal::PlainDate.new(year: @year, month: 1, day: 1)
	end

	def last_day
		Literal::PlainDate.new(year: @year, month: 12, day: 31)
	end

	def months
		(first_month..last_month)
	end

	def month(month)
		Literal::PlainYearMonth.new(year: @year, month:)
	end

	def each_month(&)
		return enum_for(__method__) { 12 } unless block_given?

		i = 1
		while i <= 12
			yield Literal::PlainYearMonth.new(year: @year, month: i)
			i += 1
		end
	end

	def each_day
		return enum_for(__method__) { self.class.days_in_year(@year) } unless block_given?

		day = first_day
		last = last_day

		while day <= last
			yield day
			day = day.next_day
		end
	end

	def january
		Literal::PlainYearMonth.new(year: @year, month: 1)
	end

	def february
		Literal::PlainYearMonth.new(year: @year, month: 2)
	end

	def march
		Literal::PlainYearMonth.new(year: @year, month: 3)
	end

	def april
		Literal::PlainYearMonth.new(year: @year, month: 4)
	end

	def may
		Literal::PlainYearMonth.new(year: @year, month: 5)
	end

	def june
		Literal::PlainYearMonth.new(year: @year, month: 6)
	end

	def july
		Literal::PlainYearMonth.new(year: @year, month: 7)
	end

	def august
		Literal::PlainYearMonth.new(year: @year, month: 8)
	end

	def september
		Literal::PlainYearMonth.new(year: @year, month: 9)
	end

	def october
		Literal::PlainYearMonth.new(year: @year, month: 10)
	end

	def november
		Literal::PlainYearMonth.new(year: @year, month: 11)
	end

	def december
		Literal::PlainYearMonth.new(year: @year, month: 12)
	end

	def leap_year?
		self.class.leap_year?(@year)
	end

	def ce?
		@year > 0
	end

	def bce?
		@year < 0
	end

	def iso8601
		@year.to_s
	end

	alias_method :to_s, :iso8601
end
