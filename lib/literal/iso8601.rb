# frozen_string_literal: true

module Literal::ISO8601
	extend self
	extend Literal::Types

	Sign = _Union(-1, 1)

	DURATION_UNIT_DESIGNATORS = {
		years: "Y",
		months: "M",
		weeks: "W",
		days: "D",
		hours: "H",
		minutes: "M",
		seconds: "S",
	}.freeze

	DurationUnit = _Union(*DURATION_UNIT_DESIGNATORS.keys)
	DURATION_UNIT_ORDER_INDEX = DURATION_UNIT_DESIGNATORS.keys.each_with_index.to_h.freeze
	FIRST_TIME_DURATION_UNIT_INDEX = DURATION_UNIT_ORDER_INDEX.fetch(:hours)
	WEEK_DURATION_UNIT = :weeks

	TimePrecision = _Union(
		:hour,
		:minute,
		:second,
	)

	FractionUnit = _Union(
		:none,
		:hour,
		:minute,
		:second,
	)

	DateNode = _Union(
		_Deferred { Literal::ISO8601::CalendarDate },
		_Deferred { Literal::ISO8601::OrdinalDate },
		_Deferred { Literal::ISO8601::WeekDate },
	)

	ZoneNode = _Union(
		_Deferred { Literal::ISO8601::LocalZone },
		_Deferred { Literal::ISO8601::UTCZone },
		_Deferred { Literal::ISO8601::OffsetZone },
	)

	IntervalEndpoint = _Union(
		DateNode,
		_Deferred { Literal::ISO8601::TimeOfDay },
		_Deferred { Literal::ISO8601::DateTime },
	)

	IntervalNode = _Union(
		_Deferred { Literal::ISO8601::IntervalStartEnd },
		_Deferred { Literal::ISO8601::IntervalStartDuration },
		_Deferred { Literal::ISO8601::IntervalDurationEnd },
	)

	ValidNode = _Predicate("ValidISO8601Node") do |value|
		Node === value && value.valid?
	end

	ValidDateNode = _Predicate("ValidISO8601DateNode") do |value|
		DateNode === value && value.valid?
	end

	ValidTimeOfDay = _Predicate("ValidISO8601TimeOfDay") do |value|
		TimeOfDay === value && value.valid?
	end

	ValidDateTime = _Predicate("ValidISO8601DateTime") do |value|
		DateTime === value && value.valid?
	end

	ValidDuration = _Predicate("ValidISO8601Duration") do |value|
		Duration === value && value.valid?
	end

	ValidInterval = _Predicate("ValidISO8601Interval") do |value|
		IntervalNode === value && value.valid?
	end

	ISO8601String = _Predicate("ISO8601String") do |value|
		String === value && Node === parse(value)
	end

	ValidISO8601String = _Predicate("ValidISO8601String") do |value|
		String === value && ValidNode === parse(value)
	end

	DateString = _Predicate("ISO8601DateString") do |value|
		String === value && DateNode === parse_date(value)
	end

	ValidDateString = _Predicate("ValidISO8601DateString") do |value|
		String === value && ValidDateNode === parse_date(value)
	end

	TimeString = _Predicate("ISO8601TimeString") do |value|
		String === value && TimeOfDay === parse_time(value)
	end

	ValidTimeString = _Predicate("ValidISO8601TimeString") do |value|
		String === value && ValidTimeOfDay === parse_time(value)
	end

	DateTimeString = _Predicate("ISO8601DateTimeString") do |value|
		String === value && DateTime === parse_date_time(value)
	end

	ValidDateTimeString = _Predicate("ValidISO8601DateTimeString") do |value|
		String === value && ValidDateTime === parse_date_time(value)
	end

	DurationString = _Predicate("ISO8601DurationString") do |value|
		String === value && Duration === parse_duration(value)
	end

	ValidDurationString = _Predicate("ValidISO8601DurationString") do |value|
		String === value && ValidDuration === parse_duration(value)
	end

	IntervalString = _Predicate("ISO8601IntervalString") do |value|
		String === value && IntervalNode === parse_interval(value)
	end

	ValidIntervalString = _Predicate("ValidISO8601IntervalString") do |value|
		String === value && ValidInterval === parse_interval(value)
	end

	# Parses any supported ISO8601 value, e.g. "2025-01-13T10:15:30Z".
	def parse(value)
		parse_or_error(value) { Parser.new(value).parse }
	end

	# Parses a date only, e.g. "2025-01-13" or "20250113".
	def parse_date(value)
		parse_or_error(value) { Parser.new(value).parse_date }
	end

	# Parses a time only, e.g. "10:15:30.25+01:30" or "101530Z".
	def parse_time(value)
		parse_or_error(value) { Parser.new(value).parse_time }
	end

	# Parses a date-time only, e.g. "2025-01-13T10:15:30+01:30".
	def parse_date_time(value)
		parse_or_error(value) { Parser.new(value).parse_date_time }
	end

	# Parses a duration only, e.g. "P1Y2M3DT4H5M6.7S".
	def parse_duration(value)
		parse_or_error(value) { Parser.new(value).parse_duration }
	end

	# Parses an interval only, e.g. "2025-01-13/P1D".
	def parse_interval(value)
		parse_or_error(value) { Parser.new(value).parse_interval }
	end

	def valid_fraction?(fraction, fraction_digits)
		return false unless fraction >= 0 && fraction_digits >= 0
		return fraction == 0 if fraction_digits == 0

		fraction < (10 ** fraction_digits)
	end

	private def parse_or_error(value)
		result = catch(Parser::THROW_TAG) do
			[:ok, yield]
		end

		return result[1] if Array === result && result[0] == :ok

		Error.new(index: result.index, message: result.message, input: value)
	end
end
