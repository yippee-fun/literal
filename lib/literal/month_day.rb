# frozen_string_literal: true

class Literal::MonthDay < Literal::Data
	include Comparable

	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)

	#: (String) -> Literal::MonthDay
	def self.parse(value)
		match = /\A--(\d{2})-(\d{2})\z/.match(value)
		raise ArgumentError unless match

		month = Integer(match[1], 10)
		day = Integer(match[2], 10)

		new(month:, day:)
	end

	#: (Literal::MonthDay, Literal::MonthDay) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> void
	private def after_initialize
		raise ArgumentError if @day > Literal::LocalMonth.days_in_month(year: 2000, month: @month)
	end

	#: (Integer) -> Literal::LocalDate
	def in_year(year)
		Literal::LocalDate.new(year:, month: @month, day: @day)
	end

	#: () -> String
	def iso8601
		"--#{format('%02d', @month)}-#{format('%02d', @day)}"
	end

	alias_method :to_s, :iso8601

	#: (month: Integer, day: Integer) -> Literal::MonthDay
	def with(month: @month, day: @day)
		Literal::MonthDay.new(month:, day:)
	end

	#: (Literal::MonthDay) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::MonthDay) -> -1 | 0 | 1
	def <=>(other)
		other => Literal::MonthDay

		[@month, @day] <=> [other.month, other.day]
	end
end
