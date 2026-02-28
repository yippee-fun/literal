# frozen_string_literal: true

module Literal::Cron
	extend self
	MACROS = {
		"@yearly" => "0 0 1 1 *",
		"@annually" => "0 0 1 1 *",
		"@monthly" => "0 0 1 * *",
		"@weekly" => "0 0 * * 0",
		"@daily" => "0 0 * * *",
		"@midnight" => "0 0 * * *",
		"@hourly" => "0 * * * *",
	}.freeze

	MONTH_ALIASES = {
		"JAN" => 1,
		"FEB" => 2,
		"MAR" => 3,
		"APR" => 4,
		"MAY" => 5,
		"JUN" => 6,
		"JUL" => 7,
		"AUG" => 8,
		"SEP" => 9,
		"OCT" => 10,
		"NOV" => 11,
		"DEC" => 12,
	}.freeze

	WEEKDAY_ALIASES = {
		"SUN" => 0,
		"MON" => 1,
		"TUE" => 2,
		"WED" => 3,
		"THU" => 4,
		"FRI" => 5,
		"SAT" => 6,
		7 => 0,
	}.freeze

	def parse(expression, start:, time_zone: nil)
		start = Literal::PlainDateTime.coerce(start)

		minute, hour, day_of_month, month, day_of_week = parse_fields(expression)

		rule = Literal::RecurrenceRule.new(
			frequency: :minutely,
			interval: 1,
			by_second: [0],
			by_minute: minute,
			by_hour: hour,
			by_day_of_month: day_of_month,
			by_month: month,
			by_day_of_week: day_of_week
		)

		Literal::Recurrence.new(start:, rule:, time_zone:)
	end

	def dump(recurrence)
		recurrence => Literal::Recurrence
		raise ArgumentError unless representable?(recurrence)

		rule = recurrence.rule

		[
			encode_field(rule.by_minute, min: 0, max: 59),
			encode_field(rule.by_hour, min: 0, max: 23),
			encode_field(rule.by_day_of_month, min: 1, max: 31),
			encode_field(rule.by_month, min: 1, max: 12),
			encode_field(rule.by_day_of_week, min: 0, max: 6),
		].join(" ")
	end

	def representable?(recurrence)
		recurrence => Literal::Recurrence
		rule = recurrence.rule

		rule.frequency == :minutely &&
			rule.interval == 1 &&
			(rule.by_second.empty? || rule.by_second == [0]) &&
			recurrence.count == nil &&
			recurrence.until == nil &&
			recurrence.exdates.empty? &&
			recurrence.rdates.empty?
	end

	private def parse_fields(expression)
		expression = normalize_expression(expression)
		fields = expression.split
		raise ArgumentError unless fields.length == 5

		minute = parse_field(fields[0], min: 0, max: 59)
		hour = parse_field(fields[1], min: 0, max: 23)
		day_of_month = parse_field(fields[2], min: 1, max: 31)
		month = parse_field(fields[3], min: 1, max: 12, aliases: MONTH_ALIASES)
		day_of_week = parse_field(fields[4], min: 0, max: 7, aliases: WEEKDAY_ALIASES)

		[minute, hour, day_of_month, month, day_of_week]
	end

	private def parse_field(field, min:, max:, aliases: {})
		return [] if field == "*"

		values = field.split(",").flat_map do |part|
			parse_part(part, min:, max:, aliases:)
		end

		values.map { |value| aliases.fetch(value, value) }.uniq.sort
	end

	private def parse_part(part, min:, max:, aliases: {})
		base, step = part.split("/", 2)
		step = if step
			Integer(step, 10)
		else
			nil
		end

		if step && step <= 0
			raise ArgumentError
		end

		values = if base == "*"
			(min..max).to_a
		elsif base.include?("-")
			left, right = base.split("-", 2)
			start_value = parse_value(left, min:, max:, aliases:)
			end_value = parse_value(right, min:, max:, aliases:)
			raise ArgumentError if start_value > end_value
			(start_value..end_value).to_a
		else
			start_value = parse_value(base, min:, max:, aliases:)
			if step
				(start_value..max).to_a
			else
				[start_value]
			end
		end

		if step
			values.each_with_index.filter_map { |value, index| value if (index % step) == 0 }
		else
			values
		end
	end

	private def parse_value(raw, min:, max:, aliases: {})
		upcased = raw.upcase
		if aliases.key?(upcased)
			value = aliases[upcased]
		else
			value = Integer(raw, 10)
		end

		value = aliases.fetch(value, value)

		raise ArgumentError unless min <= value && value <= max

		value
	end

	private def encode_field(values, min:, max:)
		return "*" if values.empty?

		normalized = values.uniq.sort
		if normalized == (min..max).to_a
			"*"
		else
			normalized.join(",")
		end
	end

	private def normalize_expression(expression)
		expression = expression.strip
		macro = expression.downcase
		if MACROS.key?(macro)
			MACROS[macro]
		elsif macro == "@reboot"
			raise ArgumentError
		else
			expression
		end
	end
end
