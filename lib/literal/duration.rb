# frozen_string_literal: true

# An abstract description of an amount of time.
# Ironically, the actual duration may not be known until it is applied to a concrete time.
class Literal::Duration < Literal::Object
	prop :years, Integer, reader: :public
	prop :months, Integer, reader: :public
	prop :days, Integer, reader: :public
	prop :hours, Integer, reader: :public
	prop :nanoseconds, Integer, reader: :public

	def initialize(
		centuries: 0,
		decades: 0,
		years: 0,
		months: 0,
		fortnights: 0,
		weeks: 0,
		days: 0,
		hours: 0,
		minutes: 0,
		seconds: 0,
		milliseconds: 0,
		microseconds: 0,
		nanoseconds: 0
	)
		years += 100 * centuries
		years += 10 * decades

		years += (months / 12)
		months %= 12

		days += 14 * fortnights
		days += 7 * weeks

		microseconds += (nanoseconds / 1000)
		nanoseconds %= 1000

		milliseconds += (microseconds / 1000)
		microseconds %= 1000

		seconds += (milliseconds / 1000)
		milliseconds %= 1000

		minutes += (seconds / 60)
		seconds %= 60

		hours += (minutes / 60)
		minutes %= 60

		seconds += (minutes * 60)
		nanoseconds += 1_000_000_000 * seconds
		nanoseconds += 1_000_000 * milliseconds
		nanoseconds += 1_000 * microseconds

		super(
			years:,
			months:,
			days:,
			hours:,
			nanoseconds:
		)
	end

	#: (Literal::Duration) -> Literal::Duration
	def +(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				years: @years + other.years,
				months: @months + other.months,
				days: @days + other.days,
				hours: @hours + other.hours,
				nanoseconds: @nanoseconds + other.nanoseconds
			)
		else
			raise ArgumentError
		end
	end

	#: (Literal::Duration) -> Literal::Duration
	def -(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				years: @years - other.years,
				months: @months - other.months,
				days: @days - other.days,
				hours: @hours - other.hours,
				nanoseconds: @nanoseconds - other.nanoseconds
			)
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::Duration
	def -@
		Literal::Duration.new(
			years: -@years,
			months: -@months,
			days: -@days,
			nanoseconds: -@nanoseconds
		)
	end
end
