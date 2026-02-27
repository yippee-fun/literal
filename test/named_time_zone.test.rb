# frozen_string_literal: true

test "named time zone class helpers" do
	named = Literal::NamedTimeZone.coerce("Europe/London")
	fixed = Literal::NamedTimeZone.coerce("+01:00")

	assert Literal::NamedTimeZone === named
	assert Literal::FixedOffsetTimeZone === fixed
	assert_equal named, ["Europe/London"].map(&Literal::NamedTimeZone).first
	assert_equal "UTC", Literal::NamedTimeZone.utc.identifier
	assert_equal Literal::NamedTimeZone.new("Europe/London"), Literal::NamedTimeZone.parse("Europe/London")
	assert Literal::NamedTimeZone === Literal::NamedTimeZone.country_zones.first
	assert Literal::NamedTimeZone === Literal::NamedTimeZone.all_zones.first
	assert_raises(ArgumentError) { Literal::NamedTimeZone.coerce(Object.new) }
end

test "named time zone instance helpers" do
	zone = Literal::NamedTimeZone.new("Europe/London")
	instant = Literal::Instant.parse("2025-01-13T20:00:00Z")

	assert_equal "Europe/London", zone.identifier
	assert_equal zone.identifier, zone.tzinfo.identifier
	assert_equal zone.identifier, zone.now.zone
	assert_equal zone.identifier, zone.to_zoned_date_time(instant).zone
	assert_equal zone.identifier, zone.to_zoned_date_time("2025-01-13T20:00:00Z").zone
	assert_equal zone.identifier, zone.at(instant).zone
	assert_equal zone.identifier, zone.at("2025-01-13T20:00:00Z").zone
	assert_equal Time.iso8601("2025-01-13T20:00:00Z"), zone.to_local_ruby_time(instant)
	assert_equal Time.iso8601("2025-01-13T20:00:00Z"), zone.to_local_ruby_time("2025-01-13T20:00:00Z")
	assert_equal 0, zone.offset_in_seconds(instant)
	assert_equal Rational(0, 1), zone.offset_in_minutes(instant)
	assert_equal Rational(0, 1), zone.offset_in_hours(instant)
	assert Literal::ZonedDateTime === zone.next_transition(instant)
	assert Literal::ZonedDateTime === zone.prev_transition(instant)
end

test "named time zone resolves ambiguous and missing local times" do
	zone = Literal::NamedTimeZone.new("Europe/London")
	ambiguous = Literal::LocalDateTime.new(year: 2025, month: 10, day: 26, hour: 1, minute: 30)
	resolution = zone.resolve_local_date_time(ambiguous)

	assert resolution.ambiguous?
	assert_equal 2, resolution.candidates.length

	earlier = resolution.disambiguate(disambiguation: :earlier)
	later = resolution.disambiguate(disambiguation: :later)
	assert earlier.to_instant < later.to_instant

	missing = Literal::LocalDateTime.new(year: 2025, month: 3, day: 30, hour: 1, minute: 30)
	missing_resolution = zone.resolve_local_date_time(missing)
	string_resolution = zone.resolve_local_date_time("2025-10-26T01:30:00")
	assert missing_resolution.missing?
	assert string_resolution.ambiguous?
	assert_raises(ArgumentError) { missing_resolution.disambiguate }
	assert_equal zone.identifier, zone.from_local_date_time(ambiguous, disambiguation: :later).zone
	assert_raises(ArgumentError) { zone.resolve_local_date_time(ambiguous, disambiguation: :nope) }
end
