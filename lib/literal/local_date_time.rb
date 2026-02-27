# frozen_string_literal: true

require "date"

class Literal::LocalDateTime < Literal::Data
	include Comparable

	ROUNDING_MODES = Literal::Instant::ROUNDING_MODES

	NANOSECONDS_PER_HOUR = 3_600_000_000_000
	NANOSECONDS_PER_MINUTE = 60_000_000_000
	NANOSECONDS_PER_SECOND = 1_000_000_000
	NANOSECONDS_PER_MILLISECOND = 1_000_000
	NANOSECONDS_PER_MICROSECOND = 1_000
	ISO8601_PATTERN = /\A(.+?)[T ](.+)\z/

	prop :year, Integer
	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)
	prop :hour, _Integer(0..24), default: 0
	prop :minute, _Integer(0..59), default: 0
	prop :second, _Integer(0..59), default: 0
	prop :millisecond, _Integer(0..999), default: 0
	prop :microsecond, _Integer(0..999), default: 0
	prop :nanosecond, _Integer(0..999), default: 0

	#: (String) -> Literal::LocalDateTime
	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise ArgumentError unless match
		raise ArgumentError if /(?:Z|[+-]\d{2}:?\d{2})\z/ === value

		local_date = Literal::LocalDate.parse(match[1])
		local_time = Literal::LocalTime.parse(match[2])
		local_time.to_local_date_time(local_date)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String) -> Literal::LocalDateTime
	def self.coerce(value)
		case value
		when Literal::LocalDateTime
			value
		when Literal::ZonedDateTime
			value.to_local_date_time
		when Literal::LocalDate
			Literal::LocalDateTime.new(year: value.year, month: value.month, day: value.day)
		when Date
			Literal::LocalDateTime.new(year: value.year, month: value.month, day: value.day)
		when Time
			total_subsec = value.nsec
			millisecond = total_subsec / 1_000_000
			remainder = total_subsec % 1_000_000
			microsecond = remainder / 1_000
			nanosecond = remainder % 1_000

			Literal::LocalDateTime.new(
				year: value.year,
				month: value.month,
				day: value.day,
				hour: value.hour,
				minute: value.min,
				second: value.sec,
				millisecond:,
				microsecond:,
				nanosecond:
			)
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

	#: (Literal::LocalDateTime, Literal::LocalDateTime) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Literal::LocalYear
	def to_year
		Literal::LocalYear.new(year: @year)
	end

	#: () -> Literal::LocalMonth
	def to_month
		Literal::LocalMonth.new(year: @year, month: @month)
	end

	#: () -> Literal::LocalDate
	def to_local_date
		Literal::LocalDate.new(year: @year, month: @month, day: @day)
	end

	#: () -> Date
	def to_date
		Date.new(@year, @month, @day)
	end

	#: () -> Literal::LocalTime
	def to_local_time
		subsec = Rational((@millisecond * 1_000_000) + (@microsecond * 1_000) + @nanosecond, 1_000_000_000)
		Literal::LocalTime.new(hour: @hour, minute: @minute, second: @second, subsec:)
	end

	#: () -> Literal::YearMonth
	def to_year_month
		Literal::YearMonth.new(year: @year, month: @month)
	end

	#: () -> Literal::MonthDay
	def to_month_day
		Literal::MonthDay.new(month: @month, day: @day)
	end

	#: () -> Date
	def to_ruby_date
		Date.new(@year, @month, @day)
	end

	#: () -> Time
	def to_ruby_time
		total_subsec = (@millisecond * 1_000_000) + (@microsecond * 1_000) + @nanosecond
		subsec_seconds = Rational(total_subsec, 1_000_000_000)
		Time.new(@year, @month, @day, @hour, @minute, @second + subsec_seconds, 0)
	end

	#: () -> String
	def iso8601
		"#{to_date.iso8601}T#{to_local_time.iso8601}"
	end

	alias_method :to_s, :iso8601

	#: (**Integer) -> Literal::LocalDateTime
	def with(
		year: @year,
		month: @month,
		day: @day,
		hour: @hour,
		minute: @minute,
		second: @second,
		millisecond: @millisecond,
		microsecond: @microsecond,
		nanosecond: @nanosecond
	)
		Literal::LocalDateTime.new(year:, month:, day:, hour:, minute:, second:, millisecond:, microsecond:, nanosecond:)
	end

	#: (Literal::LocalDateTime) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String) -> Literal::Duration
	def since(other)
		other = Literal::LocalDateTime.coerce(other)

		total = to_ruby_time.to_r - other.to_ruby_time.to_r
		seconds = total.to_i
		subseconds = total - seconds

		Literal::Duration.new(seconds:, subseconds:)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String) -> Literal::Duration
	def until(other)
		Literal::LocalDateTime.coerce(other).since(self)
	end

	#: (unit: Symbol, increment: Integer, mode: ROUNDING_MODES) -> Literal::LocalDateTime
	def round(unit:, increment: 1, mode: :half_expand)
		raise ArgumentError unless increment > 0
		raise ArgumentError unless ROUNDING_MODES === mode

		date = to_date
		time = to_local_time.round(unit:, increment:, mode:)
		if time.hour < @hour && [:hour, :hours, :minute, :minutes, :second, :seconds, :millisecond, :milliseconds, :microsecond, :microseconds, :nanosecond, :nanoseconds].include?(unit)
			date += 1
		end

		Literal::LocalDateTime.new(
			year: date.year,
			month: date.month,
			day: date.day,
			hour: time.hour,
			minute: time.minute,
			second: time.second,
			millisecond: (time.subsec * 1_000).to_i,
			microsecond: (time.subsec * 1_000_000).to_i % 1_000,
			nanosecond: (time.subsec * 1_000_000_000).to_i % 1_000
		)
	end

	#: (Literal::TimeZone | String, disambiguation: Symbol) -> Literal::ZonedDateTime
	def in_zone(time_zone, disambiguation: :compatible)
		zone = Literal::TimeZone.coerce(time_zone)

		zone.from_local_date_time(self, disambiguation:)
	end

	#: (Literal::DatePeriod) -> Literal::LocalDateTime
	def +(other)
		case other
		when Literal::DatePeriod
			year = @year
			month = @month
			day = @day
			hour = @hour
			minute = @minute
			second = @second
			millisecond = @millisecond
			microsecond = @microsecond
			nanosecond = @nanosecond

			month += other.months
			day += other.days

			if month > 12
				year += (month - 1) / 12
				month = ((month - 1) % 12) + 1
			elsif month < 1
				year -= (month.abs / 12) + 1
				month = 12 - ((month.abs - 1) % 12)
			end

			while day > (days_in_month = Literal::LocalMonth.days_in_month(year:, month:))
				day -= days_in_month
				month += 1
				if month > 12
					year += 1
					month = 1
				end
			end

			while day < 1
				month -= 1
				if month < 1
					year -= 1
					month = 12
				end
				day += Literal::LocalMonth.days_in_month(year:, month:)
			end

			hour += other.hours

			other_nanoseconds = other.nanoseconds

			hour += (other_nanoseconds / NANOSECONDS_PER_HOUR)
			other_nanoseconds %= NANOSECONDS_PER_HOUR

			minute += (other_nanoseconds / NANOSECONDS_PER_MINUTE)
			other_nanoseconds %= NANOSECONDS_PER_MINUTE

			second += (other_nanoseconds / NANOSECONDS_PER_SECOND)
			other_nanoseconds %= NANOSECONDS_PER_SECOND

			millisecond += (other_nanoseconds / NANOSECONDS_PER_MILLISECOND)
			other_nanoseconds %= NANOSECONDS_PER_MILLISECOND

			microsecond += (other_nanoseconds / NANOSECONDS_PER_MICROSECOND)
			other_nanoseconds %= NANOSECONDS_PER_MICROSECOND

			nanosecond += other_nanoseconds

			carry, nanosecond = nanosecond.divmod(1_000)
			microsecond += carry
			carry, microsecond = microsecond.divmod(1_000)
			millisecond += carry
			carry, millisecond = millisecond.divmod(1_000)
			second += carry
			carry, second = second.divmod(60)
			minute += carry
			carry, minute = minute.divmod(60)
			hour += carry

			carry, hour = hour.divmod(24)
			day += carry

			while day > (days_in_month = Literal::LocalMonth.days_in_month(year:, month:))
				day -= days_in_month
				month += 1
				if month > 12
					year += 1
					month = 1
				end
			end

			while day < 1
				month -= 1
				if month < 1
					year -= 1
					month = 12
				end
				day += Literal::LocalMonth.days_in_month(year:, month:)
			end

			Literal::LocalDateTime.new(year:, month:, day:, hour:, minute:, second:, millisecond:, microsecond:, nanosecond:)
		else
			raise ArgumentError
		end
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String) -> -1 | 0 | 1 | nil
	def <=>(other)
		other = Literal::LocalDateTime.coerce(other)

		[
			@year,
			@month,
			@day,
			@hour,
			@minute,
			@second,
			@millisecond,
			@microsecond,
			@nanosecond,
		] <=> [
			other.year,
			other.month,
			other.day,
			other.hour,
			other.minute,
			other.second,
			other.millisecond,
			other.microsecond,
			other.nanosecond,
		]
	end

	#: (Literal::DatePeriod) -> Literal::LocalDateTime
	def -(other)
		case other
		when Literal::DatePeriod
			self + (-other)
		else
			raise ArgumentError
		end
	end
end
