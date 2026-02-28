# frozen_string_literal: true

require "date"

class Literal::PlainDateTime < Literal::Data
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

	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise Literal::ArgumentError, "Invalid ISO 8601 local date time: #{value.inspect}" unless match
		raise Literal::ArgumentError, "Expected a local date time without a timezone offset, got #{value.inspect}" if /(?:Z|[+-]\d{2}:?\d{2})\z/ === value

		local_date = Literal::PlainDate.parse(match[1])
		local_time = Literal::PlainTime.parse(match[2])
		local_time.to_plain_date_time(local_date)
	end

	def self.coerce(value)
		case value
		when Literal::PlainDateTime
			value
		when Literal::ZonedDateTime
			value.to_plain_date_time
		when Literal::PlainDate
			Literal::PlainDateTime.new(year: value.year, month: value.month, day: value.day)
		when Date
			Literal::PlainDateTime.new(year: value.year, month: value.month, day: value.day)
		when Time
			total_subsec = value.nsec
			millisecond = total_subsec / 1_000_000
			remainder = total_subsec % 1_000_000
			microsecond = remainder / 1_000
			nanosecond = remainder % 1_000

			Literal::PlainDateTime.new(
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
			raise Literal::ArgumentError, "Can't coerce #{value.inspect} to a Literal::PlainDateTime"
		end
	end

	def self.to_proc
		method(:coerce).to_proc
	end


	def to_year
		Literal::PlainYear.new(year: @year)
	end

	def to_year_month
		Literal::PlainYearMonth.new(year: @year, month: @month)
	end

	def to_plain_date
		Literal::PlainDate.new(year: @year, month: @month, day: @day)
	end

	def to_date
		Date.new(@year, @month, @day)
	end

	def to_plain_time
		subsec = Rational((@millisecond * 1_000_000) + (@microsecond * 1_000) + @nanosecond, 1_000_000_000)
		Literal::PlainTime.new(hour: @hour, minute: @minute, second: @second, subsec:)
	end

	def to_month_day
		Literal::MonthDay.new(month: @month, day: @day)
	end

	def to_ruby_date
		Date.new(@year, @month, @day)
	end

	def to_ruby_time
		total_subsec = (@millisecond * 1_000_000) + (@microsecond * 1_000) + @nanosecond
		subsec_seconds = Rational(total_subsec, 1_000_000_000)
		Time.new(@year, @month, @day, @hour, @minute, @second + subsec_seconds, 0)
	end

	def iso8601
		"#{to_date.iso8601}T#{to_plain_time.iso8601}"
	end

	alias_method :to_s, :iso8601

	def since(other)
		other = Literal::PlainDateTime.coerce(other)

		total = (to_ruby_time.to_r * 1_000_000_000).to_i - (other.to_ruby_time.to_r * 1_000_000_000).to_i

		Literal::Duration.new(nanoseconds: total)
	end

	def until(other)
		Literal::PlainDateTime.coerce(other).since(self)
	end

	def round(unit:, increment: 1, mode: :half_expand)
		raise Literal::ArgumentError, "increment must be positive, got #{increment}" unless increment > 0
		raise Literal::ArgumentError, "mode must be one of #{ROUNDING_MODES.inspect}, got #{mode.inspect}" unless ROUNDING_MODES === mode

		date = to_date
		time = to_plain_time.round(unit:, increment:, mode:)
		if time.hour < @hour && [:hour, :hours, :minute, :minutes, :second, :seconds, :millisecond, :milliseconds, :microsecond, :microseconds, :nanosecond, :nanoseconds].include?(unit)
			date += 1
		end

		Literal::PlainDateTime.new(
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

	def in_zone(time_zone, disambiguation: :compatible)
		zone = Literal::NamedTimeZone.coerce(time_zone)

		zone.from_plain_date_time(self, disambiguation:)
	end

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

			while day > (days_in_month = Literal::PlainYearMonth.days_in_month(year:, month:))
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
				day += Literal::PlainYearMonth.days_in_month(year:, month:)
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

			while day > (days_in_month = Literal::PlainYearMonth.days_in_month(year:, month:))
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
				day += Literal::PlainYearMonth.days_in_month(year:, month:)
			end

			Literal::PlainDateTime.new(year:, month:, day:, hour:, minute:, second:, millisecond:, microsecond:, nanosecond:)
		else
			raise Literal::ArgumentError, "Expected a Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def -(other)
		case other
		when Literal::DatePeriod
			self + (-other)
		else
			raise Literal::ArgumentError, "Expected a Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def <=>(other)
		other = Literal::PlainDateTime.coerce(other)

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
end
