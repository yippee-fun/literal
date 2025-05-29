# frozen_string_literal: true

class Literal::Time < Literal::Object
	prop :year, Integer
	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)
	prop :hour, _Integer(0, 24), default: 0, reader: :public
	prop :minute, _Integer(0, 59), default: 0, reader: :public
	prop :second, _Integer(0, 59), default: 0, reader: :public
	prop :millisecond, _Integer(0, 999), default: 0, reader: :public
	prop :microsecond, _Integer(0, 999), default: 0, reader: :public
	prop :nanosecond, _Integer(0, 999), default: 0, reader: :public

	#: () -> void
	private def after_initialize
		freeze
	end

	#: () -> Literal::Year
	def year
		Literal::Year.new(year: @year)
	end

	#: () -> Literal::Month
	def month
		Literal::Month.new(year: @year, month: @month)
	end

	#: () -> Literal::Day
	def day
		Literal::Day.new(year: @year, month: @month, day: @day)
	end

	#: () -> Date
	def to_std_date
		Date.new(@year, @month, @day)
	end

	#: () -> Time
	def to_std_time
		total_subsec = (@millisecond * 1_000_000) + (@microsecond * 1_000) + @nanosecond
		subsec_seconds = Rational(total_subsec, 1_000_000_000)
		Time.new(@year, @month, @day, @hour, @minute, @second + subsec_seconds)
	end

	#: (Literal::Duration) -> Literal::Time
	def +(other)
		case other
		when Literal::Duration
			year = @year
			month = @month
			day = @day
			hour = @hour
			minute = @minute
			second = @second
			millisecond = @millisecond
			microsecond = @microsecond
			nanosecond = @nanosecond

			year += other.years
			month += other.months
			day += other.days

			if month > 12
				year += (month - 1) / 12
				month = ((month - 1) % 12) + 1
			elsif month < 1
				year -= (month.abs / 12) + 1
				month = 12 - ((month.abs - 1) % 12)
			end

			if day > 0
				while day > (days_in_month = Literal::Month.number_of_days_in(year:, month:))
					month += 1
					day -= days_in_month
				end
			elsif day < 0
				while day < 0
					month -= 1
					day += Literal::Month.number_of_days_in(year:, month:)
				end
			end

			other_nanoseconds = other.nanoseconds

			hour += (other_nanoseconds / 3_600_000_000_000)
			other_nanoseconds %= 3_600_000_000_000

			minute += (other_nanoseconds / 60_000_000_000)
			other_nanoseconds %= 60_000_000_000

			second += (other_nanoseconds / 1_000_000_000)
			other_nanoseconds %= 1_000_000_000

			millisecond += (other_nanoseconds / 1_000_000)
			other_nanoseconds %= 1_000_000

			microsecond += (other_nanoseconds / 1_000)
			other_nanoseconds %= 1_000

			nanosecond += other_nanoseconds

			Literal::Time.new(year:, month:, day:, hour:, minute:, second:, millisecond:, microsecond:, nanosecond:)
		else
			raise ArgumentError
		end
	end

	#: (Literal::Duration) -> Literal::Time
	def -(other)
		case other
		when Literal::Duration
			self + (-other)
		else
			raise ArgumentError
		end
	end
end
