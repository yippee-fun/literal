# frozen_string_literal: true

class Literal::YearMonth < Literal::Data
	include Comparable

	prop :year, Integer
	prop :month, _Integer(1..12)

	#: (String) -> Literal::YearMonth
	def self.parse(value)
		match = /\A(-?\d{1,})-(\d{2})\z/.match(value)
		raise ArgumentError unless match

		year = Integer(match[1], 10)
		month = Integer(match[2], 10)

		new(year:, month:)
	end

	#: (Literal::YearMonth, Literal::YearMonth) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Literal::LocalMonth
	def to_local_month
		Literal::LocalMonth.new(year:, month:)
	end

	#: (Integer) -> Literal::LocalDate
	def at_day(day)
		Literal::LocalDate.new(year:, month:, day:)
	end

	#: () -> String
	def iso8601
		"#{year}-#{format('%02d', month)}"
	end

	alias_method :to_s, :iso8601

	#: (year: Integer, month: Integer) -> Literal::YearMonth
	def with(year: @year, month: @month)
		Literal::YearMonth.new(year:, month:)
	end

	#: (Literal::YearMonth) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::YearMonth) -> -1 | 0 | 1
	def <=>(other)
		other => Literal::YearMonth

		[year, month] <=> [other.year, other.month]
	end
end
