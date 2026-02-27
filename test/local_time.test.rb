# frozen_string_literal: true

test "local time parsing and formatting" do
	time = Literal::LocalTime.parse("09:15:30.123456789")

	assert_equal "09:15:30.123456789", time.iso8601
	assert_equal time.iso8601, time.to_s
	assert_equal Literal::LocalTime.new(hour: 9, minute: 15, second: 30), Literal::LocalTime.parse("09:15:30")
	assert_raises(ArgumentError) { Literal::LocalTime.parse("9:15") }
end

test "local time to local date time helpers" do
	time = Literal::LocalTime.parse("09:15:30.123456789")
	date = Literal::LocalDate.new(year: 2025, month: 1, day: 13)
	date_time = Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 15, second: 31, millisecond: 123, microsecond: 456, nanosecond: 789)
	zoned = Literal::Instant.parse("2025-01-13T09:15:30.123456789Z").in_zone("UTC")
	expected = Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 15, second: 30, millisecond: 123, microsecond: 456, nanosecond: 789)

	assert_equal expected, time.to_local_date_time(date)
	assert_equal expected, time.to_local_date_time(year: 2025, month: 1, day: 13)
	assert_equal expected, time.to_local_date_time(Date.new(2025, 1, 13))
	assert_equal expected, time.on(date)
	assert_equal expected, time.on("2025-01-13")
	assert_equal expected, time.on(Time.new(2025, 1, 13, 0, 0, 0, 0))
	assert_equal expected.to_local_time, time.with
	assert time.equals(Literal::LocalTime.parse("09:15:30.123456789"))
	assert_equal time, ["09:15:30.123456789"].map(&Literal::LocalTime).first
	assert_equal Literal::Duration.new(nanoseconds: 1_000_000_000), time.since("09:15:29.123456789")
	assert_equal Literal::Duration.new(nanoseconds: 1_000_000_000), time.until(date_time)
	assert_equal 0, time <=> zoned
	assert_equal(-1, Literal::LocalTime.compare(Literal::LocalTime.new(hour: 9), Literal::LocalTime.new(hour: 10)))
	assert_equal 60, Literal::LocalTime.new(hour: 10).since(Literal::LocalTime.new(hour: 9, minute: 59)).seconds
	assert_equal "09:16:00", time.round(unit: :minute).iso8601
	assert_equal "09:15:30.123", time.round(unit: :millisecond).iso8601
end
