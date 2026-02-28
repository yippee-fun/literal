# frozen_string_literal: true

test "instant class helpers and formatting" do
	ruby_time = Time.iso8601("2025-01-13T20:00:00.123456789Z")
	instant = Literal::Instant.coerce(ruby_time)

	assert_equal ruby_time.to_i, instant.unix_timestamp_in_seconds
	assert Literal::Instant === Literal::Instant.now
	assert_equal "Literal::Instant(1736798400.1234567)", instant.inspect
end

test "instant parse arithmetic and zone conversion" do
	instant = Literal::Instant.parse("2025-01-13T20:00:00.123456789Z")
	duration = Literal::Duration.new(nanoseconds: 1_100_000_000)
	zoned = instant.in_zone("UTC")

	assert_equal "2025-01-13T20:00:00.123456789Z", instant.iso8601
	assert_equal instant.iso8601, instant.to_s
	assert_equal Time.iso8601("2025-01-13T20:00:00.123456789Z"), instant.to_ruby_time
	assert_equal 1_736_798_401, (instant + Literal::Duration.new(nanoseconds: 1_000_000_000)).unix_timestamp_in_seconds
	assert_equal 1_736_798_399, (instant - Literal::Duration.new(nanoseconds: 1_000_000_000)).unix_timestamp_in_seconds
	assert_equal (instant.to_i + instant.subsec).to_f, instant.to_f
	assert_equal(-1, (instant - duration) <=> instant)
	assert_equal(0, instant <=> Literal::Instant.parse("2025-01-13T20:00:00.123456789Z"))
	assert_equal(1, (instant + duration) <=> instant)
	assert_raises(ArgumentError) { instant + 1 }
	assert_raises(ArgumentError) { instant - 1 }

	assert_equal "UTC", instant.in_zone("UTC").zone
	zoned = instant.in_zone("+01:30")
	assert_equal "UTC+01:30", zoned.zone
	assert_equal Rational(3, 2), zoned.offset_in_hours
	assert_equal instant, ["2025-01-13T20:00:00.123456789Z"].map(&Literal::Instant).first
	assert_equal instant, Literal::Instant.coerce(zoned)
	assert_equal 1, instant.since("2025-01-13T19:59:59.123456789Z").seconds
	assert_equal Literal::Instant.parse("2025-01-13T20:00:00.123456789Z"), instant
	assert_equal(-1, (instant - Literal::Duration.new(nanoseconds: 1_000_000_000)) <=> instant)
	assert_equal 1, instant.since(instant - Literal::Duration.new(nanoseconds: 1_000_000_000)).seconds
	assert_equal 1, instant.until(instant + Literal::Duration.new(nanoseconds: 1_000_000_000)).seconds
	assert_equal "2025-01-13T20:00:00.000000000Z", instant.round(unit: :second).iso8601
	assert_equal "2025-01-13T20:00:00.123000000Z", instant.round(unit: :millisecond).iso8601
end
