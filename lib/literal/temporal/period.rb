# frozen_string_literal: true

# An abstract description of an amount of time, e.g. "3 months".
# The actual duration may not be known until it is applied to a concrete timestamp.
class Literal::Period < Literal::Data
	prop :months, Integer
	prop :days, Integer
	prop :nanoseconds, Integer

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
		decades += Literal::Temporal::DECADES_IN_CENTURY * centuries
		years += Literal::Temporal::YEARS_IN_A_DECADE * decades
		months += Literal::Temporal::MONTHS_IN_YEAR * years

		weeks += Literal::Temporal::WEEKS_IN_A_FORTNIGHT * fortnights
		days += Literal::Temporal::DAYS_IN_A_WEEK * weeks

		cycle_count, days = divmod_toward_zero(days, Literal::Temporal::DAYS_IN_A_400_YEAR_CYCLE)
		months += (Literal::Temporal::MONTHS_IN_YEAR * 400 * cycle_count)

		minutes += 24 * hours
		seconds += 60 * minutes
		milliseconds += 1_000 * seconds
		microseconds += 1_000 * milliseconds
		nanoseconds += 1_000 * microseconds

		super(
			months:,
			days:,
			nanoseconds:
		)
	end

	def +(other)
		case other
		when Literal::DatePeriod
			Literal::DatePeriod.new(
				months: @months + other.months,
				days: @days + other.days,
				nanoseconds: @nanoseconds + other.nanoseconds
			)
		else
			raise Literal::ArgumentError, "Cannot add #{other.inspect} to a Literal::DatePeriod"
		end
	end

	def -(other)
		case other
		when Literal::DatePeriod
			Literal::DatePeriod.new(
				months: @months - other.months,
				days: @days - other.days,
				nanoseconds: @nanoseconds - other.nanoseconds
			)
		else
			raise Literal::ArgumentError, "Cannot subtract #{other.inspect} from a Literal::DatePeriod"
		end
	end

	def -@
		Literal::DatePeriod.new(
			months: -@months,
			days: -@days,
			nanoseconds: -@nanoseconds
		)
	end

	def to_human
		normalize.map { |unit, count|
			"#{count} #{(count.abs == 1) ? unit.name[0..-2] : unit}"
		}.join(", ")
	end

	def normalize
		microseconds, nanoseconds = divmod_toward_zero(@nanoseconds, 1_000)
		milliseconds, microseconds = divmod_toward_zero(microseconds, 1_000)
		seconds, milliseconds = divmod_toward_zero(milliseconds, 1_000)
		minutes, seconds = divmod_toward_zero(seconds, 60)
		hours, minutes = divmod_toward_zero(minutes, Literal::Temporal::MINUTES_IN_AN_HOUR)

		cycles_from_hours, hours = divmod_toward_zero(hours, (Literal::Temporal::DAYS_IN_A_400_YEAR_CYCLE * Literal::Temporal::HOURS_IN_A_DAY))
		cycles_from_days, days = divmod_toward_zero(@days, Literal::Temporal::DAYS_IN_A_400_YEAR_CYCLE)

		cycles = cycles_from_days + cycles_from_hours

		months = @months + (cycles * 400 * Literal::Temporal::MONTHS_IN_YEAR)
		weeks, days = divmod_toward_zero(days, 7)
		years, months = divmod_toward_zero(months, Literal::Temporal::MONTHS_IN_YEAR)

		[
			([:years, years] if years != 0),
			([:months, months] if months != 0),
			([:weeks, weeks] if weeks != 0),
			([:days, days] if days != 0),
			([:hours, hours] if hours != 0),
			([:minutes, minutes] if minutes != 0),
			([:seconds, seconds] if seconds != 0),
			([:milliseconds, milliseconds] if milliseconds != 0),
			([:microseconds, microseconds] if microseconds != 0),
			([:nanoseconds, nanoseconds] if nanoseconds != 0),
		].compact.to_h
	end

	def inspect
		"Literal::Period(#{to_human})"
	end

	def ago(time_zone)
	end

	def from_now(time_zone)
	end

	def since(time, tz:)
	end

	def before(time, tz:)
	end

	def absolute?
		@months == 0 && @days == 0
	end

	def to_duration!
		unless absolute?
			raise "Cannot convert non-absolute period to duration"
		end

		Literal::Duration.new(ns: @nanoseconds)
	end

	private def divmod_toward_zero(value, divisor)
		if value < 0
			quotient, remainder = (-value).divmod(divisor)
			[-quotient, -remainder]
		else
			value.divmod(divisor)
		end
	end
end
