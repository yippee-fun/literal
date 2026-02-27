# frozen_string_literal: true

require "time"

# Models a point in time irrespective of time zone.
class Literal::Instant < Literal::Data
	include Comparable

	ROUNDING_MODES = _Union(:half_expand, :floor, :ceil, :trunc)

	# The number of nanoseconds since the Unix Epoch (January 1, 1970, 00:00:00 UTC).
	prop :unix_timestamp_in_nanoseconds, Integer

	#: () -> Integer
	def to_i
		@unix_timestamp_in_nanoseconds / 1_000_000_000
	end

	alias_method :unix_timestamp_in_seconds, :to_i

	#: () -> Rational
	def subsec
		Rational(@unix_timestamp_in_nanoseconds % 1_000_000_000, 1_000_000_000)
	end

	#: (Time) -> Literal::Instant
	def self.from_ruby_time(time)
		time => Time

		new(unix_timestamp_in_nanoseconds: (time.to_i * 1_000_000_000) + time.tv_nsec)
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
			raise Literal::ArgumentError, "Can’t coerce #{value.inspect} to a Literal::Instant"
		end
	end

	#: () -> Proc
	def self.to_proc
		method(:coerce).to_proc
	end

	#: () -> Literal::Instant
	def self.now
		new(unix_timestamp_in_nanoseconds: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond))
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
		Time.at(
			@unix_timestamp_in_nanoseconds / 1_000_000_000,
			@unix_timestamp_in_nanoseconds % 1_000_000_000,
			:nanosecond
		).utc
	end

	#: () -> String
	def iso8601
		to_ruby_time.iso8601(9)
	end

	alias_method :to_s, :iso8601

	#: (unix_timestamp_in_nanoseconds: Integer) -> Literal::Instant
	def with(unix_timestamp_in_nanoseconds: @unix_timestamp_in_nanoseconds)
		Literal::Instant.new(unix_timestamp_in_nanoseconds:)
	end

	#: (Literal::Duration) -> Literal::Instant
	def +(other)
		case other
		in Literal::Duration
			Literal::Instant.new(
				unix_timestamp_in_nanoseconds: @unix_timestamp_in_nanoseconds + other.nanoseconds
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

		Literal::Duration.new(
			nanoseconds: @unix_timestamp_in_nanoseconds - other.unix_timestamp_in_nanoseconds
		)
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
		rounded = round_integer(@unix_timestamp_in_nanoseconds, step, mode)

		Literal::Instant.new(unix_timestamp_in_nanoseconds: rounded)
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
		@unix_timestamp_in_nanoseconds / 1_000_000_000.0
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> -1 | 0 | 1
	def <=>(other)
		other = Literal::Instant.coerce(other)

		@unix_timestamp_in_nanoseconds <=> other.unix_timestamp_in_nanoseconds
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
