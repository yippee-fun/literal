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

	def each_month
		enum_for(__method__) { number_of_months } unless block_given?

		each_year do |year|
			year.each_month do |month|
				yield month
			end
		end
	end

	def each_day
		enum_for(__method__) { number_of_days } unless block_given?

		day = @from.first_day
		last_day = @to.last_day

		while day <= last_day
			yield day
			day = day.next_day
		end
	end

	def each_hour
		enum_for(__method__) { number_of_hours } unless block_given?

		each_day do |day|
			day.each_hour do |hour|
				yield hour
			end
		end
	end

	def each_minute
		enum_for(__method__) { number_of_minutes } unless block_given?

		each_hour do |hour|
			hour.each_minute do |minute|
				yield minute
			end
		end
	end

	def each_second
		enum_for(__method__) { number_of_seconds } unless block_given?

		each_minute do |minute|
			minute.each_second do |second|
				yield second
			end
		end
	end
end
