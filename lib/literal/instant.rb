# frozen_string_literal: true

require "time"

# Models a point in time irrespective of time zone.
class Literal::Instant < Literal::Data
	include Comparable

	ROUNDING_MODES = _Union(:half_expand, :floor, :ceil, :trunc)

	# The number of seconds since the Unix Epoch (January 1, 1970, 00:00:00 UTC).
	prop :unix_timestamp_in_seconds, Integer, reader: :public
	prop :subsec, Rational, reader: :public

	alias_method :to_i, :unix_timestamp_in_seconds

	#: () -> void
	def self.from_ruby_time(time)
		time => Time

		new(unix_timestamp_in_seconds: time.to_i, subsec: Rational(time.subsec))
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Literal::Instant
	def self.coerce(value)
		case value
		when Literal::Instant
			value
		when Literal::ZonedDateTime
			value.to_instant
		when Time
			from_ruby_time(value)
		when String
			parse(value)
		else
			raise ArgumentError
		end
	end

	#: () -> Proc
	def self.to_proc
		method(:coerce).to_proc
	end

	#: () -> Literal::Instant
	def self.now
		from_ruby_time(::Time.now)
	end

	#: (String) -> Literal::Instant
	def self.parse(value)
		from_ruby_time(Time.iso8601(value).utc)
	end

	#: (Literal::Instant, Literal::Instant) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> String
	def inspect
		"Literal::Instant(#{to_f})"
	end

	#: () -> Literal::ZonedDateTime
	def utc
		Literal::ZonedDateTime.new(instant: self, time_zone: Literal::TimeZone.utc)
	end

	#: (Literal::TimeZone | String) -> Literal::ZonedDateTime
	def in_zone(time_zone)
		Literal::TimeZone.coerce(time_zone).to_zoned_date_time(self)
	end

	#: () -> Time
	def to_ruby_time
		Time.at(unix_timestamp_in_seconds + subsec).utc
	end

	#: () -> String
	def iso8601
		to_ruby_time.iso8601(9)
	end

	alias_method :to_s, :iso8601

	#: (unix_timestamp_in_seconds: Integer, subsec: Rational) -> Literal::Instant
	def with(unix_timestamp_in_seconds: @unix_timestamp_in_seconds, subsec: @subsec)
		Literal::Instant.new(unix_timestamp_in_seconds:, subsec:)
	end

	#: (Literal::Duration) -> Literal::Instant
	def +(other)
		case other
		in Literal::Duration
			Literal::Instant.new(
				unix_timestamp_in_seconds: unix_timestamp_in_seconds + other.seconds,
				subsec: subsec + other.subseconds
			)
		else
			raise ArgumentError
		end
	end

	#: (Literal::Instant) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Literal::Duration
	def since(other)
		other = Literal::Instant.coerce(other)

		delta_seconds = unix_timestamp_in_seconds - other.unix_timestamp_in_seconds
		delta_subseconds = subsec - other.subsec

		Literal::Duration.new(seconds: delta_seconds, subseconds: delta_subseconds)
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Literal::Duration
	def until(other)
		Literal::Instant.coerce(other).since(self)
	end

	#: (unit: Symbol, increment: Integer, mode: ROUNDING_MODES) -> Literal::Instant
	def round(unit:, increment: 1, mode: :half_expand)
		raise ArgumentError unless increment > 0
		raise ArgumentError unless ROUNDING_MODES === mode

		nanos_per_unit = case unit
		in :hour | :hours
			3_600_000_000_000
		in :minute | :minutes
			60_000_000_000
		in :second | :seconds
			1_000_000_000
		in :millisecond | :milliseconds
			1_000_000
		in :microsecond | :microseconds
			1_000
		in :nanosecond | :nanoseconds
			1
		else
			raise ArgumentError
		end

		step = nanos_per_unit * increment
		total_nanos = (unix_timestamp_in_seconds * 1_000_000_000) + (subsec * 1_000_000_000).to_i
		rounded = round_integer(total_nanos, step, mode)

		seconds, nanos = rounded.divmod(1_000_000_000)
		Literal::Instant.new(unix_timestamp_in_seconds: seconds, subsec: Rational(nanos, 1_000_000_000))
	end

	#: (Literal::Duration) -> Literal::Instant
	def -(other)
		case other
		in Literal::Duration
			self + (-other)
		else
			raise ArgumentError
		end
	end

	#: () -> Float
	def to_f
		(unix_timestamp_in_seconds + subsec).to_f
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> -1 | 0 | 1
	def <=>(other)
		other = Literal::Instant.coerce(other)

		result = unix_timestamp_in_seconds <=> other.unix_timestamp_in_seconds
		return result unless result == 0
		subsec <=> other.subsec
	end

	#: (Integer, Integer, Symbol) -> Integer
	private def round_integer(value, step, mode)
		quotient, remainder = value.divmod(step)

		case mode
		in :trunc
			if value >= 0 || remainder == 0
				quotient * step
			else
				(quotient + 1) * step
			end
		in :floor
			quotient * step
		in :ceil
			((remainder == 0) ? quotient : quotient + 1) * step
		in :half_expand
			if remainder * 2 >= step
				(quotient + 1) * step
			else
				quotient * step
			end
		end
	end
end
