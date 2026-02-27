# frozen_string_literal: true

require "date"

class Literal::LocalDateTimeEnumerator < Literal::Data
	include Enumerable

	UNIT_TABLE = {
		:century => :centuries,
		:centuries => :centuries,
		:decade => :decades,
		:decades => :decades,
		:year => :years,
		:years => :years,
		:quarter => :quarters,
		:quarters => :quarters,
		:month => :months,
		:months => :months,
		:fortnight => :fortnights,
		:fortnights => :fortnights,
		:week => :weeks,
		:weeks => :weeks,
		:day => :days,
		:days => :days,
		:hour => :hours,
		:hours => :hours,
		:minute => :minutes,
		:minutes => :minutes,
		:second => :seconds,
		:seconds => :seconds,
		:millisecond => :milliseconds,
		:milliseconds => :milliseconds,
		:microsecond => :microseconds,
		:microseconds => :microseconds,
		:nanosecond => :nanoseconds,
		:nanoseconds => :nanoseconds,
	}.freeze

	UnitCoercion = -> (value) { UNIT_TABLE[value] || value }

	Unit = _Union(
		:centuries,
		:decades,
		:years,
		:quarters,
		:months,
		:fortnights,
		:weeks,
		:days,
		:hours,
		:minutes,
		:seconds,
		:milliseconds,
		:microseconds,
		:nanoseconds
	)

	prop :from, Literal::LocalDateTime
	prop :to, Literal::LocalDateTime
	prop :unit, Unit, &UnitCoercion
	prop :step, Integer

	NANOSECONDS_PER_SECOND = 1_000_000_000
	NANOSECONDS_PER_MINUTE = 60 * NANOSECONDS_PER_SECOND
	NANOSECONDS_PER_HOUR = 60 * NANOSECONDS_PER_MINUTE
	NANOSECONDS_PER_DAY = 24 * NANOSECONDS_PER_HOUR

	FIXED_UNIT_NANOSECONDS = {
		days: NANOSECONDS_PER_DAY,
		fortnights: 14 * NANOSECONDS_PER_DAY,
		weeks: 7 * NANOSECONDS_PER_DAY,
		hours: NANOSECONDS_PER_HOUR,
		minutes: NANOSECONDS_PER_MINUTE,
		seconds: NANOSECONDS_PER_SECOND,
		milliseconds: 1_000_000,
		microseconds: 1_000,
		nanoseconds: 1,
	}.freeze

	#: () -> void
	private def after_initialize
		raise ArgumentError if @step == 0
	end

	#: () -> void
	def interval
		Literal::DatePeriod.new(@unit => @step)
	end

	#: () { (Literal::LocalDateTime) -> void } -> void
	def each
		return enum_for(__method__) { estimate_size } unless block_given?

		period = interval

		if @step > 0
			value = @from
			while value <= @to
				yield value
				value += period
			end
		else
			value = @from
			while value >= @to
				yield value
				value += period
			end
		end
	end

	#: () -> Integer?
	private def estimate_size
		nanos_per_unit = FIXED_UNIT_NANOSECONDS[@unit]
		return nil unless nanos_per_unit

		delta = total_nanoseconds(@to) - total_nanoseconds(@from)
		step_size = @step * nanos_per_unit

		if step_size > 0
			return 0 if delta < 0
		else
			return 0 if delta > 0
		end

		(delta.abs / step_size.abs) + 1
	end

	#: (Literal::LocalDateTime) -> Integer
	private def total_nanoseconds(local_date_time)
		date = Date.new(local_date_time.year, local_date_time.month, local_date_time.day)
		nanos_in_day = (local_date_time.hour * NANOSECONDS_PER_HOUR) +
			(local_date_time.minute * NANOSECONDS_PER_MINUTE) +
			(local_date_time.second * NANOSECONDS_PER_SECOND) +
			(local_date_time.millisecond * 1_000_000) +
			(local_date_time.microsecond * 1_000) +
			local_date_time.nanosecond

		(date.jd * NANOSECONDS_PER_DAY) + nanos_in_day
	end
end
