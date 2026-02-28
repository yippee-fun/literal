# frozen_string_literal: true

# An abstract description of an amount of time, e.g. "3 months".
# The actual duration may not be known until it is applied to a concrete timestamp.
class Literal::DatePeriod < Literal::Data
	prop :months, Integer, reader: :public
	prop :days, Integer, reader: :public
	prop :hours, Integer, reader: :public
	prop :nanoseconds, Integer, reader: :public

	def self.divmod_toward_zero(value, divisor)
		if value < 0
			quotient, remainder = (-value).divmod(divisor)
			[-quotient, -remainder]
		else
			value.divmod(divisor)
		end
	end

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

		months += (years * 12)

		days += 14 * fortnights
		days += 7 * weeks

		# Every 146_097 days is exactly 400 years
		cycle_count, days = self.class.divmod_toward_zero(days, 146_097)
		months += (4_800 * cycle_count)

		carry, nanoseconds = self.class.divmod_toward_zero(nanoseconds, 1000)
		microseconds += carry

		carry, microseconds = self.class.divmod_toward_zero(microseconds, 1000)
		milliseconds += carry

		carry, milliseconds = self.class.divmod_toward_zero(milliseconds, 1000)
		seconds += carry

		carry, seconds = self.class.divmod_toward_zero(seconds, 60)
		minutes += carry

		carry, minutes = self.class.divmod_toward_zero(minutes, 60)
		hours += carry

		seconds += (minutes * 60)
		nanoseconds += 1_000_000_000 * seconds
		nanoseconds += 1_000_000 * milliseconds
		nanoseconds += 1_000 * microseconds

		super(
			months:,
			days:,
			hours:,
			nanoseconds:
		)
	end

	def +(other)
		case other
		when Literal::DatePeriod
			Literal::DatePeriod.new(
				months: @months + other.months,
				days: @days + other.days,
				hours: @hours + other.hours,
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
				hours: @hours - other.hours,
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
			hours: -@hours,
			nanoseconds: -@nanoseconds
		)
	end

	def ago(time_zone)
		zone = Literal::TimeZone.coerce(time_zone)

		(zone.now.to_plain_date_time - self).in_zone(zone)
	end

	def from_now(time_zone)
		zone = Literal::TimeZone.coerce(time_zone)

		(zone.now.to_plain_date_time + self).in_zone(zone)
	end
end
