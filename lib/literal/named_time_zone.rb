# frozen_string_literal: true

begin
	require "tzinfo"
rescue LoadError
	raise LoadError.new("The `tzinfo` gem is required for IANA time zones (for example \"Europe/London\"). Add `gem \"tzinfo\"` to your Gemfile or install it.")
end

class Literal::NamedTimeZone < Literal::Data
	DISAMBIGUATIONS = Literal::LocalDateTimeResolution::Disambiguation

	prop :tz, TZInfo::Timezone, :positional, reader: false do |value|
		TZInfo::Timezone.get(value)
	end

	#: (Literal::NamedTimeZone | Literal::FixedOffsetTimeZone | String) -> Literal::NamedTimeZone | Literal::FixedOffsetTimeZone
	def self.coerce(value)
		case value
		when Literal::NamedTimeZone, Literal::FixedOffsetTimeZone
			value
		when String
			begin
				Literal::FixedOffsetTimeZone.parse(value)
			rescue ArgumentError
				new(value)
			end
		else
			raise ArgumentError
		end
	end

	#: () -> Proc
	def self.to_proc
		-> (value) { coerce(value) }
	end

	#: () -> Enumerator::Lazy[Literal::NamedTimeZone]
	def self.country_zones
		TZInfo::Timezone.all_country_zone_identifiers.lazy.map { |id| new(id) }
	end

	#: () -> Enumerator::Lazy[Literal::NamedTimeZone]
	def self.all_zones
		TZInfo::Timezone.all_identifiers.lazy.map { |id| new(id) }
	end

	#: () -> Literal::NamedTimeZone
	def self.utc
		new("UTC")
	end

	#: (String) -> Literal::NamedTimeZone | Literal::FixedOffsetTimeZone
	def self.parse(value)
		coerce(value)
	end

	#: () -> String
	def identifier
		@tz.identifier
	end

	#: () -> TZInfo::Timezone
	def tzinfo
		@tz
	end

	#: () -> Literal::ZonedDateTime
	def now
		to_zoned_date_time(Literal::Instant.now)
	end

	#: (Literal::Instant) -> Literal::ZonedDateTime
	def to_zoned_date_time(instant)
		instant = Literal::Instant.coerce(instant)

		Literal::ZonedDateTime.new(
			instant:,
			time_zone: self,
		)
	end

	#: (Literal::Instant | Literal::ZonedDateTime | Time | String) -> Literal::ZonedDateTime
	def at(instant = Literal::Instant.now)
		to_zoned_date_time(instant)
	end

	#: (Literal::Instant) -> Time
	def to_local_ruby_time(instant)
		instant = Literal::Instant.coerce(instant)

		@tz.to_local(instant.to_ruby_time)
	end

	#: (Literal::Instant) -> Integer
	def offset_in_seconds(instant = Literal::Instant.now)
		instant = Literal::Instant.coerce(instant)

		@tz.period_for_utc(instant.to_ruby_time).observed_utc_offset
	end

	#: (Literal::Instant) -> Rational
	def offset_in_minutes(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 60)
	end

	#: (Literal::Instant) -> Rational
	def offset_in_hours(instant = Literal::Instant.now)
		Rational(offset_in_seconds(instant), 3_600)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String, disambiguation: DISAMBIGUATIONS) -> Literal::LocalDateTimeResolution
	def resolve_local_date_time(local_date_time, disambiguation: :compatible)
		local_date_time = Literal::LocalDateTime.coerce(local_date_time)

		raise ArgumentError unless DISAMBIGUATIONS === disambiguation

		local_ruby_time = local_date_time.to_ruby_time
		periods = @tz.periods_for_local(local_ruby_time)
		instants = periods.map do |period|
			Literal::Instant.from_ruby_time(local_ruby_time - period.observed_utc_offset)
		end

		Literal::LocalDateTimeResolution.new(
			local_date_time:,
			time_zone: self,
			instants:,
			gap: periods.empty?
		)
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String, disambiguation: DISAMBIGUATIONS) -> Literal::ZonedDateTime
	def from_local_date_time(local_date_time, disambiguation: :compatible)
		resolve_local_date_time(local_date_time, disambiguation:).disambiguate(disambiguation:)
	end

	#: (Literal::Instant) -> Literal::ZonedDateTime?
	def next_transition(instant)
		instant = Literal::Instant.coerce(instant)

		transition = @tz.transitions_up_to(Time.utc(3000, 1, 1), instant.to_ruby_time).first
		return nil unless transition

		Literal::Instant.from_ruby_time(Time.at(transition.at.to_i).utc).in_zone(self)
	end

	#: (Literal::Instant) -> Literal::ZonedDateTime?
	def prev_transition(instant)
		instant = Literal::Instant.coerce(instant)

		transition = @tz.transitions_up_to(instant.to_ruby_time, Time.utc(1900, 1, 1)).last
		return nil unless transition

		Literal::Instant.from_ruby_time(Time.at(transition.at.to_i).utc).in_zone(self)
	end
end
