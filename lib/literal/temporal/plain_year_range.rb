# frozen_string_literal: true

class Literal::PlainYearRange < Literal::Data
	prop :from, Literal::PlainYear
	prop :to, Literal::PlainYear

	def after_initialize
		unless @from < @to
			raise ArgumentError, "from must be before to"
		end
	end

	def number_of_years
		to.year - from.year + 1
	end

	def number_of_days
		year = @from.year
		ending_year = @to.year

		days = 0

		while year < ending_year
			days += Literal::Temporal.days_in_year(year:)
			year += 1
		end

		days
	end

	def number_of_hours
		number_of_days * Literal::Temporal::HOURS_IN_A_DAY
	end

	def number_of_minutes
		number_of_days * Literal::Temporal::MINUTES_IN_A_DAY
	end

	def number_of_seconds
		number_of_days * Literal::Temporal::SECONDS_IN_A_DAY
	end

	def each_year
		enum_for(__method__) { number_of_years } unless block_given?

		year = @from
		while year <= @to
			yield year
			year = year.next_year
		end
	end
end
