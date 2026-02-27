# frozen_string_literal: true

test "zoned date time exposes local fields and arithmetic" do
	instant = Literal::Instant.parse("2025-01-13T20:00:00Z")
	zoned = Literal::ZonedDateTime.new(instant:, time_zone: "+01:30")

	assert_equal "UTC", Literal::ZonedDateTime.now(Literal::TimeZone.utc).zone
	assert_equal 0, zoned.subsec
	assert_equal 0, zoned.nanosecond
	assert_equal Literal::LocalYear.new(year: 2025), zoned.to_year
	assert_equal Literal::LocalMonth.new(year: 2025, month: 1), zoned.to_month
	assert_equal Literal::LocalDate.new(year: 2025, month: 1, day: 13), zoned.to_local_date
	assert_equal Literal::LocalTime.new(hour: 21, minute: 30, second: 0, subsec: Rational(0, 1)), zoned.to_local_time
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 21, minute: 30, second: 0, millisecond: 0, microsecond: 0, nanosecond: 0), zoned.to_local_date_time
	assert_equal instant, zoned.to_instant
	assert_equal 2025, zoned.year
	assert_equal 21, zoned.hour
	assert_equal 30, zoned.minute
	assert_equal "2025-01-13T21:30:00+01:30", zoned.iso8601
	assert_equal 5_400, zoned.offset_in_seconds
	assert_equal Rational(90, 1), zoned.offset_in_minutes
	assert_equal Rational(3, 2), zoned.offset_in_hours
	assert_equal "UTC+01:30", zoned.zone
	assert_equal Date.new(2025, 1, 13), zoned.to_date
	assert_equal "2025-01-13T21:31:00+01:30", (zoned + Literal::Duration.new(seconds: 60)).iso8601
	assert_equal "2025-01-13T21:28:59+01:30", (zoned - Literal::Duration.new(seconds: 61)).iso8601
	assert_equal "2025-01-14T21:30:00+01:30", (zoned + Literal::DatePeriod.new(days: 1)).iso8601
	assert_equal "2025-01-12T21:30:00+01:30", (zoned - Literal::DatePeriod.new(days: 1)).iso8601
	assert_equal "UTC", zoned.in_zone("UTC").zone
	assert_raises(ArgumentError) { zoned + 1 }
	assert_raises(ArgumentError) { zoned - 1 }
	assert_equal "2025-01-13T21:30:00+01:30 UTC+01:30", zoned.to_s
	assert zoned.equals(Literal::ZonedDateTime.new(instant:, time_zone: "+01:30"))
	assert_equal(-1, Literal::ZonedDateTime.compare(zoned, zoned + Literal::Duration.new(seconds: 1)))
	assert_equal 1, (zoned + Literal::Duration.new(seconds: 1)).since(zoned).seconds
	assert_equal 24.0, zoned.hours_in_day
	assert_equal "2025-01-13T00:00:00+01:30", zoned.start_of_day.iso8601
	assert_equal nil, zoned.next_transition
	assert_equal nil, zoned.prev_transition
	assert_equal "2025-01-13T22:00:00+01:30", zoned.round(unit: :hour).iso8601
	assert_equal "2025-01-13T21:30:00+01:30", zoned.with.iso8601
end
