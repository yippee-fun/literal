# frozen_string_literal: true

require "date"

class Literal::LocalTime < Literal::Data
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

	#: (String) -> Literal::LocalTime
	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise ArgumentError unless match

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

	#: (Literal::LocalTime | Literal::LocalDateTime | Literal::ZonedDateTime | Time | String) -> Literal::LocalTime
	def self.coerce(value)
		case value
		when Literal::LocalTime
			value
		when Literal::LocalDateTime, Literal::ZonedDateTime
			value.to_local_time
		when Time
			new(hour: value.hour, minute: value.min, second: value.sec, subsec: Rational(value.nsec, 1_000_000_000))
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

	#: (Literal::LocalTime, Literal::LocalTime) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: (Literal::LocalDate | Date) -> Literal::LocalDateTime
	#: (year: Integer, month: Integer, day: Integer) -> Literal::LocalDateTime
	def to_local_date_time(*args)
		millisecond, microsecond, nanosecond = split_subsec

		case args
		in [{ year: Integer => year, month: Integer => month, day: Integer => day }]
			Literal::LocalDateTime.new(
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
		in [Literal::LocalDate => day]
			Literal::LocalDateTime.new(
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
			Literal::LocalDateTime.new(
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

	#: (Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Date | Time | String) -> Literal::LocalDateTime
	def on(local_date)
		to_local_date_time(Literal::LocalDate.coerce(local_date))
	end

	#: () -> String
	def iso8601
		base = "#{format('%02d', @hour)}:#{format('%02d', @minute)}:#{format('%02d', @second)}"
		fraction = format_fraction
		fraction ? "#{base}.#{fraction}" : base
	end

	alias_method :to_s, :iso8601

	#: (**Integer) -> Literal::LocalTime
	def with(hour: @hour, minute: @minute, second: @second, subsec: @subsec)
		Literal::LocalTime.new(hour:, minute:, second:, subsec:)
	end

	#: (Literal::LocalTime) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::LocalTime | Literal::LocalDateTime | Literal::ZonedDateTime | Time | String) -> Literal::Duration
	def since(other)
		other = Literal::LocalTime.coerce(other)

		Literal::Duration.new(
			seconds: 0,
			subseconds: Rational(to_total_nanoseconds - other.to_total_nanoseconds, NANOSECONDS_PER_SECOND)
		)
	end

	#: (Literal::LocalTime | Literal::LocalDateTime | Literal::ZonedDateTime | Time | String) -> Literal::Duration
	def until(other)
		Literal::LocalTime.coerce(other).since(self)
	end

	#: (unit: Symbol, increment: Integer, mode: ROUNDING_MODES) -> Literal::LocalTime
	def round(unit:, increment: 1, mode: :half_expand)
		raise ArgumentError unless increment > 0
		raise ArgumentError unless ROUNDING_MODES === mode

		base = case unit
			in :hour | :hours then NANOSECONDS_PER_HOUR
			in :minute | :minutes then NANOSECONDS_PER_MINUTE
			in :second | :seconds then NANOSECONDS_PER_SECOND
			in :millisecond | :milliseconds then 1_000_000
			in :microsecond | :microseconds then 1_000
			in :nanosecond | :nanoseconds then 1
			else raise ArgumentError
		end

		step = base * increment
		rounded = round_integer(to_total_nanoseconds, step, mode) % NANOSECONDS_PER_DAY

		hour, remainder = rounded.divmod(NANOSECONDS_PER_HOUR)
		minute, remainder = remainder.divmod(NANOSECONDS_PER_MINUTE)
		second, nanos = remainder.divmod(NANOSECONDS_PER_SECOND)

		Literal::LocalTime.new(hour:, minute:, second:, subsec: Rational(nanos, NANOSECONDS_PER_SECOND))
	end

	#: (Literal::LocalTime | Literal::LocalDateTime | Literal::ZonedDateTime | Time | String) -> -1 | 0 | 1
	def <=>(other)
		other = Literal::LocalTime.coerce(other)

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

	#: () -> Integer
	protected def to_total_nanoseconds
		(@hour * NANOSECONDS_PER_HOUR) +
			(@minute * NANOSECONDS_PER_MINUTE) +
			(@second * NANOSECONDS_PER_SECOND) +
			(@subsec * NANOSECONDS_PER_SECOND).to_i
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
