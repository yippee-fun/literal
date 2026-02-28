# frozen_string_literal: true

require "date"

class Literal::PlainTime < Literal::Data
	include Comparable

	ROUNDING_MODES = Literal::Instant::ROUNDING_MODES
	NANOSECONDS_PER_SECOND = 1_000_000_000
	NANOSECONDS_PER_MINUTE = 60 * NANOSECONDS_PER_SECOND
	NANOSECONDS_PER_HOUR = 60 * NANOSECONDS_PER_MINUTE
	NANOSECONDS_PER_DAY = 24 * NANOSECONDS_PER_HOUR

	ISO8601_PATTERN = /\A(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?\z/

	prop :hour, _Integer(0..23), default: 0
	prop :minute, _Integer(0..59), default: 0
	prop :second, _Integer(0..59), default: 0
	prop :subsec, Rational, default: Rational(0, 1_000)

	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise Literal::ArgumentError, "Invalid ISO 8601 local time: #{value.inspect}" unless match

		hour = Integer(match[1], 10)
		minute = Integer(match[2], 10)
		second = Integer(match[3] || "0", 10)
		fraction = match[4]
		subsec = if fraction
			Rational(Integer(fraction, 10), 10 ** fraction.length)
		else
			Rational(0, 1)
		end

		new(hour:, minute:, second:, subsec:)
	end

	def self.coerce(value)
		case value
		when Literal::PlainTime
			value
		when Literal::PlainDateTime, Literal::ZonedDateTime
			value.to_plain_time
		when Time
			new(hour: value.hour, minute: value.min, second: value.sec, subsec: Rational(value.nsec, 1_000_000_000))
		when String
			parse(value)
		else
			raise Literal::ArgumentError, "Can't coerce #{value.inspect} to a Literal::PlainTime"
		end
	end

	def self.to_proc
		method(:coerce).to_proc
	end

	def to_plain_date_time(*args)
		millisecond, microsecond, nanosecond = split_subsec

		case args
		in [{ year: Integer => year, month: Integer => month, day: Integer => day }]
			Literal::PlainDateTime.new(
				year:,
				month:,
				day:,
				hour:,
				minute:,
				second:,
				millisecond:,
				microsecond:,
				nanosecond:,
			)
		in [Literal::PlainDate => day]
			Literal::PlainDateTime.new(
				year: day.year,
				month: day.month,
				day: day.day,
				hour:,
				minute:,
				second:,
				millisecond:,
				microsecond:,
				nanosecond:,
			)
		in [Date => date]
			Literal::PlainDateTime.new(
				year: date.year,
				month: date.month,
				day: date.day,
				hour:,
				minute:,
				second:,
				millisecond:,
				microsecond:,
				nanosecond:,
			)
		end
	end

	def on(plain_date)
		to_plain_date_time(Literal::PlainDate.coerce(plain_date))
	end

	def iso8601
		base = "#{format('%02d', @hour)}:#{format('%02d', @minute)}:#{format('%02d', @second)}"
		fraction = format_fraction
		fraction ? "#{base}.#{fraction}" : base
	end

	alias_method :to_s, :iso8601

	def since(other)
		other = Literal::PlainTime.coerce(other)

		Literal::Duration.new(
			nanoseconds: to_total_nanoseconds - other.to_total_nanoseconds
		)
	end

	def until(other)
		Literal::PlainTime.coerce(other).since(self)
	end

	def round(unit:, increment: 1, mode: :half_expand)
		raise Literal::ArgumentError, "increment must be positive, got #{increment}" unless increment > 0
		raise Literal::ArgumentError, "mode must be one of #{ROUNDING_MODES.inspect}, got #{mode.inspect}" unless ROUNDING_MODES === mode

		base = case unit
			in :hour | :hours then NANOSECONDS_PER_HOUR
			in :minute | :minutes then NANOSECONDS_PER_MINUTE
			in :second | :seconds then NANOSECONDS_PER_SECOND
			in :millisecond | :milliseconds then 1_000_000
			in :microsecond | :microseconds then 1_000
			in :nanosecond | :nanoseconds then 1
			else raise Literal::ArgumentError, "Unknown unit #{unit.inspect}"
		end

		step = base * increment
		rounded = round_integer(to_total_nanoseconds, step, mode) % NANOSECONDS_PER_DAY

		hour, remainder = rounded.divmod(NANOSECONDS_PER_HOUR)
		minute, remainder = remainder.divmod(NANOSECONDS_PER_MINUTE)
		second, nanos = remainder.divmod(NANOSECONDS_PER_SECOND)

		Literal::PlainTime.new(hour:, minute:, second:, subsec: Rational(nanos, NANOSECONDS_PER_SECOND))
	end

	def <=>(other)
		other = Literal::PlainTime.coerce(other)

		to_total_nanoseconds <=> other.to_total_nanoseconds
	end

	private def split_subsec
		total_nanoseconds = (@subsec * 1_000_000_000).to_i
		millisecond = total_nanoseconds / 1_000_000
		remainder = total_nanoseconds % 1_000_000
		microsecond = remainder / 1_000
		nanosecond = remainder % 1_000
		[millisecond, microsecond, nanosecond]
	end

	private def format_fraction
		nanos = (@subsec * 1_000_000_000).to_i
		return nil if nanos == 0

		format("%09d", nanos).sub(/0+\z/, "")
	end

	protected def to_total_nanoseconds
		(@hour * NANOSECONDS_PER_HOUR) +
			(@minute * NANOSECONDS_PER_MINUTE) +
			(@second * NANOSECONDS_PER_SECOND) +
			(@subsec * NANOSECONDS_PER_SECOND).to_i
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
