# frozen_string_literal: true

require "date"

# Location based instant in time, handles DST automatically.
class Literal::ZonedDateTime < Literal::Data
	include Comparable

	ROUNDING_MODES = Literal::Instant::ROUNDING_MODES

	prop :instant, Literal::Instant
	prop :time_zone, _Deferred { Literal::TimeZone }

	def self.now(time_zone)
		time_zone.now
	end

	private def after_initialize
		@offset_in_seconds = @time_zone.offset_in_seconds(@instant)
		@year, @month, @day, @hour, @minute, @second, @subsecond_nanoseconds = local_components_for_offset_in_seconds(@offset_in_seconds)
	end

	private def local_components_for_offset_in_seconds(offset_in_seconds)
		local_nanoseconds = @instant.unix_timestamp_in_nanoseconds + (offset_in_seconds * 1_000_000_000)
		total_seconds, subsecond_nanoseconds = local_nanoseconds.divmod(1_000_000_000)
		days_since_epoch, second_of_day = total_seconds.divmod(86_400)

		year, month, day = civil_from_days(days_since_epoch)
		hour, remainder = second_of_day.divmod(3_600)
		minute, second = remainder.divmod(60)

		[year, month, day, hour, minute, second, subsecond_nanoseconds]
	end

	private def civil_from_days(days_since_epoch)
		z = days_since_epoch + 719_468
		era = ((z >= 0) ? z : z - 146_096) / 146_097
		days_of_era = z - (era * 146_097)
		year_of_era = (days_of_era - (days_of_era / 1_460) + (days_of_era / 36_524) - (days_of_era / 146_096)) / 365
		year = year_of_era + (era * 400)
		day_of_year = days_of_era - ((365 * year_of_era) + (year_of_era / 4) - (year_of_era / 100))
		month_prime = ((5 * day_of_year) + 2) / 153
		day = day_of_year - (((153 * month_prime) + 2) / 5) + 1
		month = month_prime + ((month_prime < 10) ? 3 : -9)
		year += 1 if month <= 2

		[year, month, day]
	end

	def year
		@year
	end

	def month
		@month
	end

	def day
		@day
	end

	def hour
		@hour
	end

	def minute
		@minute
	end

	def second
		@second
	end

	def subsec
		Rational(@subsecond_nanoseconds, 1_000_000_000)
	end

	def nanosecond
		@subsecond_nanoseconds % 1_000
	end

	def to_year
		Literal::PlainYear.new(year:)
	end

	def to_year_month
		Literal::PlainYearMonth.new(year:, month:)
	end

	def to_plain_date
		Literal::PlainDate.new(year: @year, month: @month, day: @day)
	end

	def to_date
		Date.new(@year, @month, @day)
	end

	def to_plain_time
		Literal::PlainTime.new(
			hour: @hour,
			minute: @minute,
			second: @second,
			subsec: Rational(@subsecond_nanoseconds, 1_000_000_000)
		)
	end

	def to_plain_date_time
		millisecond = @subsecond_nanoseconds / 1_000_000
		remainder = @subsecond_nanoseconds % 1_000_000
		microsecond = remainder / 1_000
		nanosecond = remainder % 1_000

		Literal::PlainDateTime.new(
			year: @year,
			month: @month,
			day: @day,
			hour: @hour,
			minute: @minute,
			second: @second,
			millisecond:,
			microsecond:,
			nanosecond:
		)
	end

	def to_instant
		@instant
	end

	def in_zone(time_zone)
		@instant.in_zone(time_zone)
	end

	def since(other)
		case other
		in Literal::ZonedDateTime
			to_instant.since(other.to_instant)
		else
			raise Literal::ArgumentError, "Expected a Literal::ZonedDateTime, got #{other.inspect}"
		end
	end

	def until(other)
		other.since(self)
	end

	def round(unit:, increment: 1, mode: :half_expand)
		to_plain_date_time.round(unit:, increment:, mode:).in_zone(@time_zone)
	end

	def +(other)
		case other
		when Literal::Duration
			Literal::ZonedDateTime.new(instant: @instant + other, time_zone: @time_zone)
		when Literal::DatePeriod
			(to_plain_date_time + other).in_zone(@time_zone)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration or Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def -(other)
		case other
		when Literal::Duration, Literal::DatePeriod
			self + (-other)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration or Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def offset_in_seconds
		@offset_in_seconds
	end

	def offset_in_minutes
		Rational(@offset_in_seconds, 60)
	end

	def offset_in_hours
		Rational(@offset_in_seconds, 3_600)
	end

	def hours_in_day
		start = start_of_day.to_instant
		next_start = to_plain_date.next_day.at(hour: 0).in_zone(@time_zone).start_of_day.to_instant
		next_start.since(start).to_f / 3600
	end

	def start_of_day
		local = Literal::PlainDateTime.new(year:, month:, day:, hour: 0, minute: 0, second: 0)
		resolution = @time_zone.resolve_local_date_time(local, disambiguation: :earlier)

		return resolution.disambiguate(disambiguation: :earlier) unless resolution.missing?

		minute = 1
		while minute < 1_440
			candidate = Literal::PlainDateTime.new(year:, month:, day:, hour: minute / 60, minute: minute % 60, second: 0)
			resolution = @time_zone.resolve_local_date_time(candidate, disambiguation: :earlier)
			return resolution.disambiguate(disambiguation: :earlier) unless resolution.missing?
			minute += 1
		end

		raise Literal::ArgumentError, "No valid local time found at start of day in zone #{@time_zone.identifier.inspect}"
	end

	def next_transition
		return nil unless @time_zone.respond_to?(:next_transition)

		@time_zone.next_transition(@instant)
	end

	def prev_transition
		return nil unless @time_zone.respond_to?(:prev_transition)

		@time_zone.prev_transition(@instant)
	end

	def zone
		@time_zone.identifier
	end

	def iso8601
		seconds = offset_in_seconds
		sign = (seconds < 0) ? "-" : "+"
		absolute = seconds.abs
		hours = absolute / 3600
		minutes = (absolute % 3600) / 60

		"#{to_plain_date_time.iso8601}#{sign}#{format('%02d', hours)}:#{format('%02d', minutes)}"
	end

	def <=>(other)
		case other
		in Literal::ZonedDateTime
			@instant <=> other.to_instant
		else
			nil
		end
	end

	def to_s
		"#{iso8601} #{zone}"
	end
end
