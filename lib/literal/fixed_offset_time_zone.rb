# frozen_string_literal: true

class Literal::FixedOffsetTimeZone < Literal::Data
	OFFSET_PATTERN = /\A(?:UTC)?([+-])(\d{1,2})(?::?(\d{2}))?\z/

	prop :offset_in_seconds, Integer
	prop :identifier, String

	#: (String) -> Literal::FixedOffsetTimeZone
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

	#: () -> Proc
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

	#: (Integer) -> String
	def self.format_identifier(offset_in_seconds)
		sign = (offset_in_seconds < 0) ? "-" : "+"
		abs = offset_in_seconds.abs
		hours = abs / 3600
		minutes = (abs % 3600) / 60
		"UTC#{sign}#{format('%02d', hours)}:#{format('%02d', minutes)}"
	end

	#: () -> Literal::FixedOffsetTimeZone
	def self.utc
		new(offset_in_seconds: 0, identifier: "UTC")
	end

	#: () -> Literal::ZonedDateTime
	def now
		to_zoned_date_time(Literal::Instant.now)
	end

	#: (Literal::Instant) -> Literal::ZonedDateTime
	def to_zoned_date_time(instant)
		instant = Literal::Instant.coerce(instant)

		Literal::ZonedDateTime.new(instant:, time_zone: self)
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Literal::ZonedDateTime
	def at(instant = Literal::Instant.now)
		to_zoned_date_time(instant)
	end

	#: (Literal::Instant) -> Time
	def to_local_ruby_time(instant)
		instant = Literal::Instant.coerce(instant)

		instant.to_ruby_time + @offset_in_seconds
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Integer
	def offset_in_seconds(_instant = Literal::Instant.now)
		@offset_in_seconds
	end

	#: (Literal::Instant) -> Rational
	def offset_in_minutes(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 60)
	end

	#: (Literal::Instant) -> Rational
	def offset_in_hours(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 3_600)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String, disambiguation: Symbol) -> Literal::LocalDateTimeResolution
	def resolve_local_date_time(local_date_time, disambiguation: :compatible)
		local_date_time = Literal::LocalDateTime.coerce(local_date_time)

		raise ArgumentError unless Literal::LocalDateTimeResolution::Disambiguation === disambiguation

		utc_seconds = local_date_time.to_ruby_time.to_r - @offset_in_seconds
		instant = Literal::Instant.from_ruby_time(Time.at(utc_seconds).utc)

		Literal::LocalDateTimeResolution.new(
			local_date_time:,
			time_zone: self,
			instants: [instant]
		)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String, disambiguation: Symbol) -> Literal::ZonedDateTime
	def from_local_date_time(local_date_time, disambiguation: :compatible)
		resolve_local_date_time(local_date_time, disambiguation:).disambiguate(disambiguation:)
	end

	#: (Literal::Instant) -> nil
	def next_transition(_instant)
		nil
	end

	#: (Literal::Instant) -> nil
	def prev_transition(_instant)
		nil
	end
end
