# frozen_string_literal: true

require "date"

# An abstract description of an amount of time, e.g. "3 months".
# The actual duration may not be known until it is applied to a concrete timestamp.
class Literal::DatePeriod < Literal::Data
	NANOSECONDS_PER_SECOND = 1_000_000_000
	NANOSECONDS_PER_MINUTE = 60 * NANOSECONDS_PER_SECOND
	NANOSECONDS_PER_HOUR = 60 * NANOSECONDS_PER_MINUTE
	UNIX_EPOCH_DATE = Literal::LocalDate.new(year: 1970, month: 1, day: 1)

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

	#: (Integer, Integer) -> [Integer, Integer]
	def self.divmod_toward_zero(value, divisor)
		if value < 0
			quotient, remainder = (-value).divmod(divisor)
			[-quotient, -remainder]
		else
			value.divmod(divisor)
		end
	end

	#: (Literal::DatePeriod) -> Literal::DatePeriod
	def +(other)
		case other
		in Literal::DatePeriod
			Literal::DatePeriod.new(
				months: @months + other.months,
				days: @days + other.days,
				hours: @hours + other.hours,
				nanoseconds: @nanoseconds + other.nanoseconds
			)
		end
	end

	#: (Literal::DatePeriod) -> Literal::DatePeriod
	def -(other)
		case other
		in Literal::DatePeriod
			Literal::DatePeriod.new(
				months: @months - other.months,
				days: @days - other.days,
				hours: @hours - other.hours,
				nanoseconds: @nanoseconds - other.nanoseconds
			)
		end
	end

	#: () -> Literal::DatePeriod
	def -@
		Literal::DatePeriod.new(
			months: -@months,
			days: -@days,
			hours: -@hours,
			nanoseconds: -@nanoseconds
		)
	end

	#: (Literal::DatePeriod | Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalTime | Date | Time | String) -> bool
	def include?(other)
		begin
			other = coerce_to_date_period(other)
		rescue ArgumentError
			return false
		end
		return false unless other

		components = [
			[@months, other.months],
			[@days, other.days],
			[@hours, other.hours],
			[@nanoseconds, other.nanoseconds],
		]

		pivot = components.find { |(boundary, _)| boundary != 0 }
		return components.all? { |(_, value)| value == 0 } unless pivot

		factor = Rational(pivot[1], pivot[0])
		return false if factor < 0 || factor > 1

		components.all? { |(boundary, value)| value == (boundary * factor) }
	end

	#: (Literal::DatePeriod | Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalTime | Date | Time | String) -> bool
	def cover?(other)
		begin
			other = coerce_to_date_period(other)
		rescue ArgumentError
			return false
		end
		return false unless other

		component_covers?(@months, other.months) &&
			component_covers?(@days, other.days) &&
			component_covers?(@hours, other.hours) &&
			component_covers?(@nanoseconds, other.nanoseconds)
	end

	#: (Literal::TimeZone | String) -> Literal::ZonedDateTime
	def ago(time_zone)
		zone = case time_zone
			when Literal::TimeZone then time_zone
			when String then Literal::TimeZone.parse(time_zone)
			else raise ArgumentError
		end

		(zone.now.to_local_date_time - self).in_zone(zone)
	end

	#: (Literal::TimeZone | String) -> Literal::ZonedDateTime
	def from_now(time_zone)
		zone = case time_zone
			when Literal::TimeZone then time_zone
			when String then Literal::TimeZone.parse(time_zone)
			else raise ArgumentError
		end

		(zone.now.to_local_date_time + self).in_zone(zone)
	end

	#: (months: Integer, days: Integer, hours: Integer, nanoseconds: Integer) -> Literal::DatePeriod
	def with(months: @months, days: @days, hours: @hours, nanoseconds: @nanoseconds)
		Literal::DatePeriod.new(months:, days:, hours:, nanoseconds:)
	end

	#: (Literal::DatePeriod) -> bool
	def equals(other)
		self == other
	end

	#: (Integer, Integer) -> bool
	private def component_covers?(boundary, value)
		if boundary > 0
			0 <= value && value <= boundary
		elsif boundary < 0
			boundary <= value && value <= 0
		else
			value == 0
		end
	end

	#: (Literal::DatePeriod | Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalTime | Date | Time | String) -> Literal::DatePeriod?
	private def coerce_to_date_period(value)
		case value
		when Literal::DatePeriod
			value
		when Literal::LocalDate
			value.since(UNIX_EPOCH_DATE)
		when Date
			Literal::LocalDate.coerce(value).since(UNIX_EPOCH_DATE)
		when Literal::LocalDateTime
			date_period = coerce_to_date_period(value.to_local_date)
			time_period = coerce_to_date_period(value.to_local_time)

			Literal::DatePeriod.new(
				months: date_period.months,
				days: date_period.days,
				hours: time_period.hours,
				nanoseconds: time_period.nanoseconds
			)
		when Literal::LocalTime
			total_nanoseconds = (value.minute * NANOSECONDS_PER_MINUTE) + (value.second * NANOSECONDS_PER_SECOND) + ((value.subsec * NANOSECONDS_PER_SECOND).to_i)
			Literal::DatePeriod.new(hours: value.hour, nanoseconds: total_nanoseconds)
		when Literal::ZonedDateTime, Time, String
			coerce_to_date_period(Literal::LocalDateTime.coerce(value))
		end
	end
end
