# frozen_string_literal: true

begin
	require "tzinfo"
rescue LoadError
	raise LoadError.new("The `tzinfo` gem is required for IANA time zones (for example \"Europe/London\"). Add `gem \"tzinfo\"` to your Gemfile or install it.")
end

class Literal::NamedTimeZone < Literal::TimeZone
	Disambiguation = Literal::PlainDateTimeResolution::Disambiguation

	prop :tz, TZInfo::Timezone, :positional, reader: false do |value|
		TZInfo::Timezone.get(value)
	end

	def self.coerce(value)
		case value
		when Literal::TimeZone
			value
		when String
			new(value)
		else
			raise ArgumentError, "Cannot coerce #{value.inspect} into a Literal::TimeZone"
		end
	end

	def self.country_zones
		TZInfo::Timezone.all_country_zone_identifiers.lazy.map { |id| new(id) }
	end

	def self.all_zones
		TZInfo::Timezone.all_identifiers.lazy.map { |id| new(id) }
	end

	def self.utc
		new("UTC")
	end

	def self.parse(value)
		coerce(value)
	end

	def identifier
		@tz.identifier
	end

	def tzinfo
		@tz
	end

	def to_local_ruby_time(instant)
		instant = Literal::Instant.coerce(instant)

		@tz.to_local(instant.to_ruby_time)
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

	def offset_in_seconds(instant = Literal::Instant.now)
		instant = Literal::Instant.coerce(instant)

		@tz.period_for_utc(instant.to_ruby_time).observed_utc_offset
	end

	def resolve_local_date_time(local_date_time, disambiguation: :compatible)
		local_date_time = Literal::PlainDateTime.coerce(local_date_time)

		raise ArgumentError unless disambiguation in Disambiguation

		local_ruby_time = local_date_time.to_ruby_time
		periods = @tz.periods_for_local(local_ruby_time)
		instants = periods.map do |period|
			Literal::Instant.coerce(local_ruby_time - period.observed_utc_offset)
		end

		Literal::PlainDateTimeResolution.new(
			plain_date_time: local_date_time,
			time_zone: self,
			instants:,
			gap: periods.empty?
		)
	end

	def next_transition(instant)
		instant = Literal::Instant.coerce(instant)

		transition = @tz.transitions_up_to(Time.utc(3000, 1, 1), instant.to_ruby_time).first
		return nil unless transition

		Literal::Instant.coerce(Time.at(transition.at.to_i).utc).in_zone(self)
	end

	def prev_transition(instant)
		instant = Literal::Instant.coerce(instant)

		transition = @tz.transitions_up_to(instant.to_ruby_time, Time.utc(1900, 1, 1)).last
		return nil unless transition

		Literal::Instant.coerce(Time.at(transition.at.to_i).utc).in_zone(self)
	end
end
