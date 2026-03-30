# frozen_string_literal: true

class Literal::ISO8601::Parser
	THROW_TAG = :literal_iso8601_parse_error
	M = "M".getbyte(0)
	DURATION_UNIT_BY_DESIGNATOR =
		Literal::ISO8601::DURATION_UNIT_DESIGNATORS.each_with_object({}) do |(unit, designator), unit_by_designator|
			byte = designator.getbyte(0)
			next if byte == M

			unit_by_designator[byte] = unit
		end.freeze

	DASH  = 45
	PLUS  = 43
	COMMA = 44
	DOT   = 46
	SLASH = 47
	COLON = 58
	T     = 84
	W     = 87
	Z     = 90
	P     = 80
	R     = 82

	def initialize(value)
		@value = value
		@index = 0
	end

	def parse
		node =
			try_parse(:parse_repeating_interval_node) ||
			try_parse(:parse_interval_node) ||
			try_parse(:parse_duration_node) ||
			try_parse(:parse_date_time_node) ||
			try_parse(:parse_date_node) ||
			try_parse(:parse_time_node)

		fail_parse("expected an ISO8601 value") unless node

		expect_eof
		node
	end

	def parse_date
		node = parse_date_node
		expect_eof
		node
	end

	def parse_time
		node = parse_time_node
		expect_eof
		node
	end

	def parse_date_time
		node = parse_date_time_node
		expect_eof
		node
	end

	def parse_duration
		node = parse_duration_node
		expect_eof
		node
	end

	def parse_interval
		node = parse_interval_node
		expect_eof
		node
	end

	private def parse_repeating_interval_node
		expect_byte(R, "expected 'R' to start repeating interval")
		repetitions = digit?(peek) ? read_variable_digits(minimum: 1) : -1
		expect_byte(SLASH, "expected '/' after repeat designator")

		Literal::ISO8601::RepeatingInterval.new(
			repetitions:,
			interval: parse_interval_node,
		)
	end

	private def parse_interval_node
		left = parse_interval_part
		expect_byte(SLASH, "expected '/' in interval")
		right = parse_interval_part

		if Literal::ISO8601::Duration === left
			fail_parse("interval cannot have duration on both sides") if Literal::ISO8601::Duration === right
			Literal::ISO8601::IntervalDurationEnd.new(duration: left, ending: right)
		elsif Literal::ISO8601::Duration === right
			Literal::ISO8601::IntervalStartDuration.new(start: left, duration: right)
		else
			Literal::ISO8601::IntervalStartEnd.new(start: left, ending: right)
		end
	end

	private def parse_interval_part
		if duration_start?
			parse_duration_node
		else
			parse_temporal_point_node
		end
	end

	private def parse_temporal_point_node
		mark = @index
		date = try_parse(:parse_date_node)
		if date
			if consume_byte(T)
				return Literal::ISO8601::DateTime.new(date:, time: parse_time_node)
			end

			return date
		end

		@index = mark
		parse_time_node
	end

	private def parse_date_time_node
		date = parse_date_node
		expect_byte(T, "expected 'T' between date and time")
		time = parse_time_node

		Literal::ISO8601::DateTime.new(date:, time:)
	end

	private def parse_date_node
		sign = 1
		signed_year = false
		if consume_byte(PLUS)
			signed_year = true
		elsif consume_byte(DASH)
			signed_year = true
			sign = -1
		end

		if signed_year
			year = sign * read_variable_digits(minimum: 4)
			expect_byte(DASH, "expected '-' after signed year")
			return parse_extended_date_tail(year)
		end

		if peek(4) == DASH
			year = read_fixed_digits(4)
			expect_byte(DASH, "expected '-' after year")
			return parse_extended_date_tail(year)
		end

		year = read_fixed_digits(4)

		if consume_byte(W)
			week = read_fixed_digits(2)
			weekday = digit?(peek) ? read_fixed_digits(1) : 0
			return Literal::ISO8601::WeekDate.new(year:, week:, weekday:)
		end

		value, count = read_upto_digits(4)
		if count == 3
			return Literal::ISO8601::OrdinalDate.new(year:, day_of_year: value)
		elsif count == 4
			return Literal::ISO8601::CalendarDate.new(year:, month: value / 100, day: value % 100)
		end

		fail_parse("expected basic calendar, ordinal, or week date")
	end

	private def parse_extended_date_tail(year)
		if consume_byte(W)
			week = read_fixed_digits(2)
			weekday = 0
			if consume_byte(DASH)
				weekday = read_fixed_digits(1)
			end
			return Literal::ISO8601::WeekDate.new(year:, week:, weekday:)
		end

		part = read_fixed_digits(2)
		if consume_byte(DASH)
			return Literal::ISO8601::CalendarDate.new(year:, month: part, day: read_fixed_digits(2))
		end

		Literal::ISO8601::OrdinalDate.new(year:, day_of_year: (part * 10) + read_fixed_digits(1))
	end

	private def parse_time_node
		hour = read_fixed_digits(2)
		minute = 0
		second = 0
		precision = :hour

		if consume_byte(COLON)
			minute = read_fixed_digits(2)
			precision = :minute
			if consume_byte(COLON)
				second = read_fixed_digits(2)
				precision = :second
			end
		elsif digit?(peek)
			minute = read_fixed_digits(2)
			precision = :minute
			if digit?(peek)
				second = read_fixed_digits(2)
				precision = :second
			end
		end

		fraction = 0
		fraction_digits = 0
		fraction_unit = :none
		if consume_byte(DOT) || consume_byte(COMMA)
			fraction, fraction_digits = read_digits_with_count(minimum: 1)
			fraction_unit = precision
		end

		Literal::ISO8601::TimeOfDay.new(
			hour:,
			minute:,
			second:,
			precision:,
			fraction:,
			fraction_digits:,
			fraction_unit:,
			zone: parse_zone_node,
		)
	end

	private def parse_zone_node
		return Literal::ISO8601::UTCZone.new if consume_byte(Z)

		sign = if consume_byte(PLUS)
			1
		elsif consume_byte(DASH)
			-1
		else
			return Literal::ISO8601::LocalZone.new
		end

		hours = read_fixed_digits(2)
		minutes = 0
		if consume_byte(COLON)
			minutes = read_fixed_digits(2)
		elsif digit?(peek)
			minutes = read_fixed_digits(2)
		end

		Literal::ISO8601::OffsetZone.new(sign:, hours:, minutes:)
	end

	private def parse_duration_node
		sign = if consume_byte(PLUS)
			1
		elsif consume_byte(DASH)
			-1
		else
			1
		end

		expect_byte(P, "expected 'P' to start duration")

		components = []
		in_time = false
		seen_component = false

		while (byte = peek)
			break if byte == SLASH

			if byte == T
				step
				in_time = true
				next
			end

			value, _digits = read_digits_with_count(minimum: 1)
			fraction = 0
			fraction_digits = 0
			if consume_byte(DOT) || consume_byte(COMMA)
				fraction, fraction_digits = read_digits_with_count(minimum: 1)
			end

			unit = parse_duration_unit(in_time)
			components << Literal::ISO8601::DurationComponent.new(unit:, value:, fraction:, fraction_digits:)
			seen_component = true
		end

		fail_parse("duration must contain at least one component") unless seen_component

		Literal::ISO8601::Duration.new(sign:, components:)
	end

	private def parse_duration_unit(in_time)
		designator = scan
		if designator == M
			return in_time ? :minutes : :months
		end

		unit = DURATION_UNIT_BY_DESIGNATOR[designator]
		return unit if unit

		fail_parse("expected duration unit designator")
	end

	private def duration_start?
		if peek == P
			true
		elsif (peek == PLUS || peek == DASH) && peek(1) == P
			true
		else
			false
		end
	end

	private def try_parse(method_name)
		mark = @index
		result = catch(THROW_TAG) do
			[:ok, __send__(method_name)]
		end

		return result[1] if Array === result && result[0] == :ok

		@index = mark
		nil
	end

	private def expect_eof
		fail_parse("unexpected trailing content") unless peek.nil?
	end

	private def expect_byte(expected, message)
		if peek == expected
			step
		else
			fail_parse(message)
		end
	end

	private def consume_byte(expected)
		return false unless peek == expected

		step
		true
	end

	private def read_fixed_digits(count)
		value = 0
		i = 0
		while i < count
			byte = peek
			fail_parse("expected #{count} digits") unless digit?(byte)
			value = (value * 10) + (byte - 48)
			step
			i += 1
		end
		value
	end

	private def read_variable_digits(minimum: 1)
		value, count = read_digits_with_count(minimum:)
		return value if count >= minimum

		fail_parse("expected at least #{minimum} digits")
	end

	private def read_digits_with_count(minimum: 1)
		value = 0
		count = 0
		while (byte = peek) && digit?(byte)
			value = (value * 10) + (byte - 48)
			step
			count += 1
		end

		fail_parse("expected at least #{minimum} digits") if count < minimum

		[value, count]
	end

	private def read_upto_digits(maximum)
		value = 0
		count = 0
		while count < maximum && (byte = peek) && digit?(byte)
			value = (value * 10) + (byte - 48)
			step
			count += 1
		end
		[value, count]
	end

	private def digit?(byte)
		byte && byte >= 48 && byte <= 57
	end

	private def peek(offset = 0)
		@value.getbyte(@index + offset)
	end

	private def step(count = 1)
		@index += count
	end

	private def scan
		byte = peek
		step
		byte
	end

	private def fail_parse(message)
		throw THROW_TAG, Literal::ISO8601::ParseError.new(message, @index)
	end
end
