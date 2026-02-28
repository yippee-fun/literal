# frozen_string_literal: true

class Literal::PlainYear < Literal::Data
	include Comparable

	prop :year, Integer

	def leap_year?
		Literal::Temporal.days_in_year(year: @year)
	end

	def ce?
		Literal::Temporal.ce?(year: @year)
	end

	def bce?
		Literal::Temporal.bce?(year: @year)
	end

	def iso8601
		@year.to_s
	end

	def days_in_year    = Literal::Temporal.days_in_year(year: @year)
	def hours_in_year   = Literal::Temporal.hours_in_year(year: @year)
	def minutes_in_year = Literal::Temporal.minutes_in_year(year: @year)
	def seconds_in_year = Literal::Temporal.seconds_in_year(year: @year)

	alias_method :to_s, :iso8601

	def next_year
		self.class.new(year: @year + 1)
	end

	def prev_year
		self.class.new(year: @year - 1)
	end

	alias_method :succ, :next_year
	alias_method :pred, :prev_year

	def <=>(other)
		case other
		when Literal::PlainYear
			@year <=> other.year
		else
			nil
		end
	end

	def month(month)
		Literal::PlainYearMonth.new(year: @year, month:)
	end

	def first_month = january
	def last_month = december

	def first_day = Literal::PlainDate.new(year: @year, month: 1, day: 1)
	def last_day = Literal::PlainDate.new(year: @year, month: 12, day: 31)

	# TODO: first_hour, first_minute, first_second
	# TODO: last_hour, last_minute, last_second

	def each_month(&)
		return enum_for(__method__) { 12 } unless block_given?

		month = first_month
		last = last_month

		while month <= last
			yield month
			month = month.next_month
		end
	end

	# TODO: define each_week

	def each_day
		return enum_for(__method__) { days_in_year } unless block_given?

		day = first_day
		last = last_day

		while day <= last
			yield day
			day = day.next_day
		end
	end

	# TODO: each_hour, each_minute, each_second

	def january   = Literal::PlainYearMonth.new(year: @year, month: 1)
	def february  = Literal::PlainYearMonth.new(year: @year, month: 2)
	def march     = Literal::PlainYearMonth.new(year: @year, month: 3)
	def april     = Literal::PlainYearMonth.new(year: @year, month: 4)
	def may       = Literal::PlainYearMonth.new(year: @year, month: 5)
	def june      = Literal::PlainYearMonth.new(year: @year, month: 6)
	def july      = Literal::PlainYearMonth.new(year: @year, month: 7)
	def august    = Literal::PlainYearMonth.new(year: @year, month: 8)
	def september = Literal::PlainYearMonth.new(year: @year, month: 9)
	def october   = Literal::PlainYearMonth.new(year: @year, month: 10)
	def november  = Literal::PlainYearMonth.new(year: @year, month: 11)
	def december  = Literal::PlainYearMonth.new(year: @year, month: 12)

	alias_method :jan, :january
	alias_method :feb, :february
	alias_method :mar, :march
	alias_method :apr, :april
	alias_method :may, :may
	alias_method :jun, :june
	alias_method :jul, :july
	alias_method :aug, :august
	alias_method :sep, :september
	alias_method :oct, :october
	alias_method :nov, :november
	alias_method :dec, :december
end
