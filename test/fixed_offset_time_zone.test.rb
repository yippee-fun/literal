# frozen_string_literal: true

test "fixed offset time zone parsing and resolution" do
	zone = Literal::FixedOffsetTimeZone.parse("UTC+01:30")
	local_date_time = Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 9)
	instant = Literal::Instant.parse("2025-01-13T07:30:00Z")

	assert_equal "UTC+01:30", Literal::FixedOffsetTimeZone.format_identifier(5400)
	assert_equal "UTC-01:30", Literal::FixedOffsetTimeZone.format_identifier(-5400)
	assert_equal "UTC", Literal::FixedOffsetTimeZone.utc.identifier
	assert_equal zone, ["+01:30"].map(&Literal::FixedOffsetTimeZone).first
	assert_raises(ArgumentError) { Literal::FixedOffsetTimeZone.parse("UTC+24:00") }
	assert_equal 5400, zone.offset_in_seconds
	assert_equal "UTC+01:30", zone.identifier
	assert Literal::TimeZone === zone
	assert_equal zone.identifier, zone.now.zone
	assert_equal zone.identifier, zone.to_zoned_date_time(instant).zone
	assert_equal zone.identifier, zone.to_zoned_date_time("2025-01-13T07:30:00Z").zone
	assert_equal zone.identifier, zone.at(instant).zone
	assert_equal Time.iso8601("2025-01-13T09:00:00Z"), zone.to_local_ruby_time(instant)
	assert_equal Time.iso8601("2025-01-13T09:00:00Z"), zone.to_local_ruby_time("2025-01-13T07:30:00Z")
	assert_equal Rational(90, 1), zone.offset_in_minutes
	assert_equal Rational(3, 2), zone.offset_in_hours

	resolution = zone.resolve_local_date_time(local_date_time)
	resolution_from_string = zone.resolve_local_date_time("2025-01-13T09:00:00")
	assert resolution.resolved?
	assert resolution_from_string.resolved?
	assert_equal zone.identifier, resolution.time_zone.identifier
	assert_equal Rational(3, 2), resolution.disambiguate.offset_in_hours
	assert_equal zone.identifier, zone.from_local_date_time(local_date_time).zone
	assert_equal nil, zone.next_transition(instant)
	assert_equal nil, zone.prev_transition(instant)
	assert_raises(ArgumentError) { zone.resolve_local_date_time(Object.new) }
	assert_raises(ArgumentError) { zone.resolve_local_date_time(local_date_time, disambiguation: :nope) }
end
