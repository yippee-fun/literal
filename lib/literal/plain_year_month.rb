# frozen_string_literal: true

class Literal::PlainYearMonth < Literal::Data
	include Comparable

	MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].freeze
	SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].freeze
	NON_LEAP_YEAR_DAY_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze
	ISO8601_PATTERN = /\A(-?\d{1,})-(\d{2})\z/

	prop :year, Integer
	prop :month, _Integer(1..12)

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

	def next_month
		if @month < 12
			self.class.new(year: @year, month: @month + 1)
		else
			self.class.new(year: @year + 1, month: 1)
		end
	end

	alias_method :succ, :next_month

	def prev_month
		if @month > 1
			self.class.new(year: @year, month: @month - 1)
		else
			self.class.new(year: @year - 1, month: 12)
		end
	end

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

	def at_day(day)
		Literal::PlainDate.new(year: @year, month: @month, day:)
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

	def number_of_days
		self.class.days_in_month(year: @year, month: @month)
	end

	def days
		(first_day..last_day)
	end

	def each_day
		total = number_of_days
		return enum_for(__method__) { total } unless block_given?

		day = 1
		while day <= total
			yield Literal::PlainDate.new(year: @year, month: @month, day:)
			day += 1
		end
	end

	def first_day
		Literal::PlainDate.new(year: @year, month: @month, day: 1)
	end

	def last_day
		Literal::PlainDate.new(year: @year, month: @month, day: number_of_days)
	end

	def january?
		1 == @month
	end

	def february?
		2 == @month
	end

	def march?
		3 == @month
	end

	def april?
		4 == @month
	end

	def may?
		5 == @month
	end

	def june?
		6 == @month
	end

	def july?
		7 == @month
	end

	def august?
		8 == @month
	end

	def september?
		9 == @month
	end

	def october?
		10 == @month
	end

	def november?
		11 == @month
	end

	def december?
		12 == @month
	end
end
