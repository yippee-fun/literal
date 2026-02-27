# frozen_string_literal: true

require "date"

# Location based instant in time, handles DST automatically.
class Literal::ZonedDateTime < Literal::Data
	ROUNDING_MODES = Literal::Instant::ROUNDING_MODES

	prop :instant, Literal::Instant
	prop :time_zone, _Deferred { Literal::TimeZone } do |value|
		case value
		when Literal::FixedOffsetTimeZone
			value
		when String
			Literal::TimeZone.coerce(value)
		else
			Literal::TimeZone.coerce(value)
		end
	end

	#: (Literal::TimeZone) -> Literal::ZonedDateTime
	def self.now(time_zone)
		time_zone.now
	end

	#: (Literal::ZonedDateTime, Literal::ZonedDateTime) -> -1 | 0 | 1
	def self.compare(one, two)
		one.to_instant <=> two.to_instant
	end

	private def after_initialize
		local_time = @time_zone.to_local_ruby_time(@instant)

		@year = local_time.year
		@month = local_time.month
		@day = local_time.day
		@hour = local_time.hour
		@minute = local_time.min
		@second = local_time.sec
		@subsec = local_time.subsec
	end

	#: () -> Integer
	attr_reader :year

	#: () -> Integer
	attr_reader :month

	#: () -> Integer
	attr_reader :day

	#: () -> Integer
	attr_reader :hour

	#: () -> Integer
	attr_reader :minute

	#: () -> Integer
	attr_reader :second

	#: () -> Rational
	attr_reader :subsec

	#: () -> Integer
	def nanosecond
		(@subsec * 1_000_000_000).to_i % 1_000
	end

	#: () -> Literal::LocalYear
	def to_year
		Literal::LocalYear.new(year:)
	end

	#: () -> Literal::LocalMonth
	def to_month
		Literal::LocalMonth.new(year:, month:)
	end

	#: () -> Literal::LocalDate
	def to_local_date
		Literal::LocalDate.new(year:, month:, day:)
	end

	#: () -> Date
	def to_date
		Date.new(year, month, day)
	end

	#: () -> Literal::LocalTime
	def to_local_time
		Literal::LocalTime.new(hour:, minute:, second:, subsec: Rational(@subsec))
	end

	#: () -> Literal::LocalDateTime
	def to_local_date_time
		total_nanoseconds = (@subsec * 1_000_000_000).to_i
		millisecond = total_nanoseconds / 1_000_000
		remainder = total_nanoseconds % 1_000_000
		microsecond = remainder / 1_000
		nanosecond = remainder % 1_000

		Literal::LocalDateTime.new(
			year:,
			month:,
			day:,
			hour:,
			minute:,
			second:,
			millisecond:,
			microsecond:,
			nanosecond:
		)
	end

	#: () -> Literal::Instant
	def to_instant
		@instant
	end

	#: (Literal::TimeZone | String) -> Literal::ZonedDateTime
	def in_zone(time_zone)
		@instant.in_zone(time_zone)
	end

	#: (?year: Integer, ?month: Integer, ?day: Integer, ?hour: Integer, ?minute: Integer, ?second: Integer, ?millisecond: Integer, ?microsecond: Integer, ?nanosecond: Integer) -> Literal::ZonedDateTime
	def with(**parts)
		to_local_date_time.with(**parts).in_zone(@time_zone)
	end

	#: (Literal::ZonedDateTime) -> bool
	def equals(other)
		case other
		when Literal::ZonedDateTime
			to_instant == other.to_instant && zone == other.zone
		else
			false
		end
	end

	#: (Literal::ZonedDateTime) -> Literal::Duration
	def since(other)
		other => Literal::ZonedDateTime
		to_instant.since(other.to_instant)
	end

	#: (Literal::ZonedDateTime) -> Literal::Duration
	def until(other)
		other.since(self)
	end

	#: (unit: Symbol, increment: Integer, mode: ROUNDING_MODES) -> Literal::ZonedDateTime
	def round(unit:, increment: 1, mode: :half_expand)
		to_local_date_time.round(unit:, increment:, mode:).in_zone(@time_zone)
	end

	#: (Literal::Duration | Literal::DatePeriod) -> Literal::ZonedDateTime
	def +(other)
		case other
		when Literal::Duration
			Literal::ZonedDateTime.new(instant: @instant + other, time_zone: @time_zone)
		when Literal::DatePeriod
			(to_local_date_time + other).in_zone(@time_zone)
		else
			raise ArgumentError
		end
	end

	#: (Literal::Duration | Literal::DatePeriod) -> Literal::ZonedDateTime
	def -(other)
		case other
		when Literal::Duration, Literal::DatePeriod
			self + (-other)
		else
			raise ArgumentError
		end
	end

	#: () -> Integer
	def offset_in_seconds
		@time_zone.offset_in_seconds(@instant)
	end

	#: () -> Rational
	def offset_in_minutes
		@time_zone.offset_in_minutes(@instant)
	end

	#: () -> Rational
	def offset_in_hours
		@time_zone.offset_in_hours(@instant)
	end

	#: () -> Rational
	def hours_in_day
		start = start_of_day.to_instant
		next_start = to_local_date.next_day.at(hour: 0).in_zone(@time_zone).start_of_day.to_instant
		next_start.since(start).to_f / 3600
	end

	#: () -> Literal::ZonedDateTime
	def start_of_day
		local = Literal::LocalDateTime.new(year:, month:, day:, hour: 0, minute: 0, second: 0)
		resolution = @time_zone.resolve_local_date_time(local, disambiguation: :earlier)

		return resolution.disambiguate(disambiguation: :earlier) unless resolution.missing?

		minute = 1
		while minute < 1_440
			candidate = Literal::LocalDateTime.new(year:, month:, day:, hour: minute / 60, minute: minute % 60, second: 0)
			resolution = @time_zone.resolve_local_date_time(candidate, disambiguation: :earlier)
			return resolution.disambiguate(disambiguation: :earlier) unless resolution.missing?
			minute += 1
		end

		raise ArgumentError
	end

	#: () -> Literal::ZonedDateTime?
	def next_transition
		return nil unless @time_zone.respond_to?(:next_transition)

		@time_zone.next_transition(@instant)
	end

	#: () -> Literal::ZonedDateTime?
	def prev_transition
		return nil unless @time_zone.respond_to?(:prev_transition)

		@time_zone.prev_transition(@instant)
	end

	#: () -> String
	def zone
		@time_zone.identifier
	end

	#: () -> String
	def iso8601
		seconds = offset_in_seconds
		sign = (seconds < 0) ? "-" : "+"
		absolute = seconds.abs
		hours = absolute / 3600
		minutes = (absolute % 3600) / 60

		"#{to_local_date_time.iso8601}#{sign}#{format('%02d', hours)}:#{format('%02d', minutes)}"
	end

	#: () -> String
	def to_s
		"#{iso8601} #{zone}"
	end
end
