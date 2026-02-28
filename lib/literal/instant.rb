# frozen_string_literal: true

require "time"

# Models a point in time irrespective of time zone.
class Literal::Instant < Literal::Data
	include Comparable

	ROUNDING_MODES = _Union(:half_expand, :floor, :ceil, :trunc)

	# The number of nanoseconds since the Unix Epoch (January 1, 1970, 00:00:00 UTC).
	prop :unix_timestamp_in_nanoseconds, Integer

	def self.coerce(value)
		case value
		when Literal::Instant
			value
		when Literal::ZonedDateTime
			value.to_instant
		when Time
			new(unix_timestamp_in_nanoseconds: (value.to_i * 1_000_000_000) + value.tv_nsec)
		when String
			parse(value)
		else
			raise Literal::ArgumentError, "Can't coerce #{value.inspect} to a Literal::Instant"
		end
	end

	def self.to_proc
		method(:coerce).to_proc
	end

	def self.now
		new(
			unix_timestamp_in_nanoseconds: Process.clock_gettime(
				Process::CLOCK_REALTIME, :nanosecond
			)
		)
	end

	def self.parse(value)
		coerce(Time.iso8601(value).utc)
	end

	def succ
		Literal::Instant.new(unix_timestamp_in_nanoseconds: @unix_timestamp_in_nanoseconds + 1)
	end

	def pred
		Literal::Instant.new(unix_timestamp_in_nanoseconds: @unix_timestamp_in_nanoseconds - 1)
	end

	def unix_timestamp_in_seconds
		@unix_timestamp_in_nanoseconds / 1_000_000_000
	end

	alias_method :to_i, :unix_timestamp_in_seconds

	def subsec
		Rational(@unix_timestamp_in_nanoseconds % 1_000_000_000, 1_000_000_000)
	end

	def inspect
		"Literal::Instant(#{to_f})"
	end

	def in_zone(time_zone)
		Literal::NamedTimeZone.coerce(time_zone).to_zoned_date_time(self)
	end

	def to_ruby_time
		Time.at(
			@unix_timestamp_in_nanoseconds / 1_000_000_000,
			@unix_timestamp_in_nanoseconds % 1_000_000_000,
			:nanosecond
		).utc
	end

	def iso8601
		to_ruby_time.iso8601(9)
	end

	alias_method :to_s, :iso8601

	def +(other)
		case other
		when Literal::Duration
			Literal::Instant.new(
				unix_timestamp_in_nanoseconds: @unix_timestamp_in_nanoseconds + other.nanoseconds
			)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}"
		end
	end

	def -(other)
		case other
		when Literal::Duration
			self + (-other)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}"
		end
	end

	def since(other)
		other = Literal::Instant.coerce(other)

		Literal::Duration.new(
			nanoseconds: @unix_timestamp_in_nanoseconds - other.unix_timestamp_in_nanoseconds
		)
	end

	def until(other)
		Literal::Instant.coerce(other).since(self)
	end

	def round(unit:, increment: 1, mode: :half_expand)
		raise Literal::ArgumentError, "increment must be positive, got #{increment}" unless increment > 0
		raise Literal::ArgumentError, "mode must be one of #{ROUNDING_MODES.inspect}, got #{mode.inspect}" unless ROUNDING_MODES === mode

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
			raise Literal::ArgumentError, "Unknown unit #{unit.inspect}"
		end

		step = nanos_per_unit * increment
		rounded = round_integer(@unix_timestamp_in_nanoseconds, step, mode)

		Literal::Instant.new(unix_timestamp_in_nanoseconds: rounded)
	end

	def to_f
		@unix_timestamp_in_nanoseconds / 1_000_000_000.0
	end

	def <=>(other)
		case other
		when Literal::Instant, Literal::ZonedDateTime, Time
			@unix_timestamp_in_nanoseconds <=> Literal::Instant.coerce(other).unix_timestamp_in_nanoseconds
		else
			nil
		end
	end

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
