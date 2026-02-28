# frozen_string_literal: true

class Literal::PlainYearMonth < Literal::Data
	include Comparable

	MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].freeze
	SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].freeze
	NON_LEAP_YEAR_DAY_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze
	ISO8601_PATTERN = /\A(-?\d{1,})-(\d{2})\z/

	prop :year, Integer
	prop :month, _Integer(1..12)

	def self.coerce(value)
		case value
		in Literal::PlainYearMonth
			value
		in ISO8601_PATTERN
			parse(value)
		in Literal::PlainDate | Literal::PlainDateTime
			new(year: value.year, month: value.month)
		in { year: Integer => year, month: Literal::Temporal::MonthInt => month }
			new(year:, month:)
		in [Integer => year, Literal::Temporal::MonthInt => month]
			new(year:, month:)
		else
			raise Literal::ArgumentError, "Invalid year-month: #{value.inspect}"
		end
	end

	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise Literal::ArgumentError, "Invalid ISO 8601 year-month: #{value.inspect}" unless match

		year = Integer(match[1], 10)
		month = Integer(match[2], 10)

		new(year:, month:)
	end

	def self.days_in_month(year:, month:)
		if month == 2 && Literal::PlainYear.leap_year?(year)
			29
		else
			NON_LEAP_YEAR_DAY_IN_MONTH[month - 1]
		end
	end

	def self.hours_in_month(year:, month:)
		days_in_month(year:, month:) * 24
	end

	def self.minutes_in_month(year:, month:)
		hours_in_month(year:, month:) * 60
	end

	def self.seconds_in_month(year:, month:)
		minutes_in_month(year:, month:) * 60
	end

	def next_month
		if @month < 12
			self.class.new(year: @year, month: @month + 1)
		else
			self.class.new(year: @year + 1, month: 1)
		end
	end

	def prev_month
		if @month > 1
			self.class.new(year: @year, month: @month - 1)
		else
			self.class.new(year: @year - 1, month: 12)
		end
	end

	alias_method :succ, :next_month
	alias_method :pred, :prev_month

	def <=>(other)
		case other
		when Literal::PlainYearMonth
			if @year == other.year
				@month <=> other.month
			else
				@year <=> other.year
			end
		else
			nil
		end
	end

	def to_year
		Literal::PlainYear.new(year: @year)
	end

	def iso8601
		"#{@year}-#{format('%02d', @month)}"
	end

	alias_method :to_s, :iso8601

	def name
		MONTH_NAMES[@month - 1]
	end

	def short_name
		SHORT_MONTH_NAMES[@month - 1]
	end

	def days_in_month    = self.class.days_in_month(year: @year, month: @month)
	def hours_in_month   = self.class.hours_in_month(year: @year, month: @month)
	def minutes_in_month = self.class.minutes_in_month(year: @year, month: @month)
	def seconds_in_month = self.class.seconds_in_month(year: @year, month: @month)

	def first_day
		Literal::PlainDate.new(year: @year, month: @month, day: 1)
	end

	def last_day
		Literal::PlainDate.new(year: @year, month: @month, day: days_in_month)
	end

	def each_day
		return enum_for(__method__) { days_in_month } unless block_given?

		day = first_day
		last = last_day

		while first_day <= last
			yield(day)
			day = day.next_day
		end
	end

	def january?   = @month == 1
	def february?  = @month == 2
	def march?     = @month == 3
	def april?     = @month == 4
	def may?       = @month == 5
	def june?      = @month == 6
	def july?      = @month == 7
	def august?    = @month == 8
	def september? = @month == 9
	def october?   = @month == 10
	def november?  = @month == 11
	def december?  = @month == 12

	alias_method :jan?, :january?
	alias_method :feb?, :february?
	alias_method :mar?, :march?
	alias_method :apr?, :april?
	alias_method :may?, :may?
	alias_method :jun?, :june?
	alias_method :jul?, :july?
	alias_method :aug?, :august?
	alias_method :sep?, :september?
	alias_method :oct?, :october?
	alias_method :nov?, :november?
	alias_method :dec?, :december?
end
