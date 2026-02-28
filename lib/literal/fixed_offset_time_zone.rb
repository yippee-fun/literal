# frozen_string_literal: true

class Literal::FixedOffsetTimeZone < Literal::TimeZone
	OFFSET_PATTERN = /\A(?:UTC)?([+-])(\d{1,2})(?::?(\d{2}))?\z/

	prop :offset_in_seconds, Integer
	prop :identifier, String

	def self.parse(value)
		match = OFFSET_PATTERN.match(value)
		raise ArgumentError unless match

		sign = (match[1] == "+") ? 1 : -1
		hours = Integer(match[2], 10)
		minutes = Integer(match[3] || "0", 10)
		raise ArgumentError if hours > 23 || minutes > 59

		total = sign * ((hours * 3600) + (minutes * 60))

		new(offset_in_seconds: total, identifier: format_identifier(total))
	end

	def self.to_proc
		proc do |value|
			case value
			when Literal::FixedOffsetTimeZone
				value
			when String
				parse(value)
			end
		end
	end

	def self.format_identifier(offset_in_seconds)
		sign = (offset_in_seconds < 0) ? "-" : "+"
		abs = offset_in_seconds.abs
		hours = abs / 3600
		minutes = (abs % 3600) / 60
		"UTC#{sign}#{format('%02d', hours)}:#{format('%02d', minutes)}"
	end

	def self.utc
		new(offset_in_seconds: 0, identifier: "UTC")
	end

	def to_local_ruby_time(instant)
		instant = Literal::Instant.coerce(instant)

		instant.to_ruby_time + @offset_in_seconds
	end

	def to_plain_date_time(instant)
		local_ruby_time = to_local_ruby_time(instant)
		total_nanoseconds = (local_ruby_time.subsec * 1_000_000_000).to_i
		millisecond = total_nanoseconds / 1_000_000
		remainder = total_nanoseconds % 1_000_000
		microsecond = remainder / 1_000
		nanosecond = remainder % 1_000

		Literal::PlainDateTime.new(
			year: local_ruby_time.year,
			month: local_ruby_time.month,
			day: local_ruby_time.day,
			hour: local_ruby_time.hour,
			minute: local_ruby_time.min,
			second: local_ruby_time.sec,
			millisecond:,
			microsecond:,
			nanosecond:
		)
	end

	def offset_in_seconds(_instant = Literal::Instant.now)
		@offset_in_seconds
	end

	def resolve_local_date_time(local_date_time, disambiguation: :compatible)
		local_date_time = Literal::PlainDateTime.coerce(local_date_time)

		raise ArgumentError unless Literal::PlainDateTimeResolution::Disambiguation === disambiguation

		utc_seconds = local_date_time.to_ruby_time.to_r - @offset_in_seconds
		instant = Literal::Instant.coerce(Time.at(utc_seconds).utc)

		Literal::PlainDateTimeResolution.new(
			plain_date_time: local_date_time,
			time_zone: self,
			instants: [instant]
		)
	end

	def next_transition(_instant)
		nil
	end

	def prev_transition(_instant)
		nil
	end
end
