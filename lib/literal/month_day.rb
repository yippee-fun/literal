# frozen_string_literal: true

class Literal::MonthDay < Literal::Data
	include Comparable

	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)

	def self.parse(value)
		match = /\A--(\d{2})-(\d{2})\z/.match(value)
		raise ArgumentError unless match

		month = Integer(match[1], 10)
		day = Integer(match[2], 10)

		new(month:, day:)
	end


	private def after_initialize
		raise ArgumentError if @day > Literal::PlainYearMonth.days_in_month(year: 2000, month: @month)
	end

	def in_year(year)
		Literal::PlainDate.new(year:, month: @month, day: @day)
	end

	def iso8601
		"--#{format('%02d', @month)}-#{format('%02d', @day)}"
	end

	alias_method :to_s, :iso8601

	def <=>(other)
		case other
		in Literal::MonthDay
			[@month, @day] <=> [other.month, other.day]
		else
			raise Literal::ArgumentError
		end
	end
end
