# frozen_string_literal: true

class Literal::MonthDay < Literal::Data
	include Comparable

	prop :month, Literal::Temporal::MonthInt
	prop :day, Literal::Temporal::DayInt

	def after_initialize
		if @day > Literal::Temporal::DAYS_IN_MONTH_ON_LEAP_YEAR[@month]
			raise ArgumentError, "day out of range for month, even on a leap year"
		end
	end

	def next_month
		Literal::MonthDay.new(
			month: (@month + 1) % Literal::Temporal::MONTHS_IN_YEAR,
			day: [@day, Literal::Temporal::DAYS_IN_MONTH_ON_LEAP_YEAR[@month]].min
		)
	end

	def prev_month
		Literal::MonthDay.new(
			month: (@month - 1) % Literal::Temporal::MONTHS_IN_YEAR,
			day: [@day, Literal::Temporal::DAYS_IN_MONTH_ON_LEAP_YEAR[@month]].min
		)
	end

	def next_day
		if @day >= Literal::Temporal::DAYS_IN_MONTH_ON_LEAP_YEAR[@month]
			Literal::MonthDay.new(
				month: (@month + 1) % Literal::Temporal::MONTHS_IN_YEAR,
				day: 1
			)
		else
			Literal::MonthDay.new(
				month: @month,
				day: @day + 1
			)
		end
	end

	def prev_day
		if @day == 1
			Literal::MonthDay.new(
				month: (@month - 1) % Literal::Temporal::MONTHS_IN_YEAR,
				day: Literal::Temporal::DAYS_IN_MONTH_ON_LEAP_YEAR[@month]
			)
		else
			Literal::MonthDay.new(
				month: @month,
				day: @day - 1
			)
		end
	end

	def <=>(other)
		case other
		when Literal::MonthDay
			[@month, @day] <=> [other.month, other.day]
		end
	end
end
