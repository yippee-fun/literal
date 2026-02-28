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
		local_time = @time_zone.to_local_ruby_time(@instant)

		@year = local_time.year
		@month = local_time.month
		@day = local_time.day
		@hour = local_time.hour
		@minute = local_time.min
		@second = local_time.sec
		@subsec = local_time.subsec
	end

	attr_reader :year

	attr_reader :month

	attr_reader :day

	attr_reader :hour

	attr_reader :minute

	attr_reader :second

	attr_reader :subsec

	def nanosecond
		(@subsec * 1_000_000_000).to_i % 1_000
	end

	def to_year
		Literal::PlainYear.new(year:)
	end

	def to_year_month
		Literal::PlainYearMonth.new(year:, month:)
	end

	def to_plain_date
		Literal::PlainDate.new(year:, month:, day:)
	end

	def to_date
		Date.new(year, month, day)
	end

	def to_plain_time
		Literal::PlainTime.new(hour:, minute:, second:, subsec: Rational(@subsec))
	end

	def to_plain_date_time
		total_nanoseconds = (@subsec * 1_000_000_000).to_i
		millisecond = total_nanoseconds / 1_000_000
		remainder = total_nanoseconds % 1_000_000
		microsecond = remainder / 1_000
		nanosecond = remainder % 1_000

		Literal::PlainDateTime.new(
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
		@time_zone.offset_in_seconds(@instant)
	end

	def offset_in_minutes
		@time_zone.offset_in_minutes(@instant)
	end

	def offset_in_hours
		@time_zone.offset_in_hours(@instant)
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
