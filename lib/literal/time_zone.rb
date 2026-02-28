# frozen_string_literal: true

class Literal::TimeZone < Literal::Data
	def self.coerce(value)
		case value
		when Literal::TimeZone
			value
		when String
			if Literal::FixedOffsetTimeZone::OFFSET_PATTERN === value
				Literal::FixedOffsetTimeZone.parse(value)
			else
				Literal::NamedTimeZone.new(value)
			end
		else
			raise Literal::ArgumentError, "Cannot coerce #{value.inspect} into a Literal::TimeZone"
		end
	end

	def now
		to_zoned_date_time(Literal::Instant.now)
	end

	def at(instant = Literal::Instant.now)
		to_zoned_date_time(instant)
	end

	def to_zoned_date_time(instant)
		instant = Literal::Instant.coerce(instant)

		Literal::ZonedDateTime.new(instant:, time_zone: self)
	end

	def offset_in_minutes(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 60)
	end

	def offset_in_hours(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 3_600)
	end

	def from_plain_date_time(plain_date_time, disambiguation: :compatible)
		resolve_local_date_time(plain_date_time, disambiguation:).disambiguate(disambiguation:)
	end
end
