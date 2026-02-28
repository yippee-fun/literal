# frozen_string_literal: true

test "local date time parse and conversions" do
	local_date_time = Literal::PlainDateTime.parse("2025-01-13T10:15:30.250001002")

	assert_equal Literal::PlainYear.new(year: 2025), local_date_time.to_year
	assert_equal Literal::PlainYearMonth.new(year: 2025, month: 1), local_date_time.to_year_month
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 13), local_date_time.to_plain_date
	assert_equal "2025-01-13T10:15:30.250001002", local_date_time.iso8601
	assert_equal local_date_time.iso8601, local_date_time.to_s
	assert_equal Date.new(2025, 1, 13), local_date_time.to_date
	assert_equal Literal::PlainTime.new(hour: 10, minute: 15, second: 30, subsec: Rational(250_001_002, 1_000_000_000)), local_date_time.to_plain_time
	assert_equal Literal::MonthDay.new(month: 1, day: 13), local_date_time.to_month_day
	assert_equal Date.new(2025, 1, 13), local_date_time.to_ruby_date
	assert_equal Time.new(2025, 1, 13, 10, 15, 30 + Rational(250_001_002, 1_000_000_000), 0), local_date_time.to_ruby_time
	assert_raises(ArgumentError) { Literal::PlainDateTime.parse("2025-01-13T10:15:30Z") }
end

test "local date time adds date period" do
	local_date_time = Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10)
	zoned = Literal::Instant.parse("2025-01-13T10:00:00Z").in_zone("UTC")

	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 14, hour: 12), local_date_time + Literal::DatePeriod.new(days: 1, hours: 2)
	assert_equal local_date_time, local_date_time - Literal::DatePeriod.new(days: 0)
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 12, hour: 8), local_date_time - Literal::DatePeriod.new(days: 1, hours: 2)
	assert_equal "UTC", local_date_time.in_zone("UTC").zone
	assert_equal(-1, local_date_time <=> Literal::PlainDateTime.new(year: 2025, month: 1, day: 14, hour: 10))
	assert_equal 0, local_date_time <=> Time.new(2025, 1, 13, 10, 0, 0, 0)
	assert_equal 1, local_date_time <=> Date.new(2025, 1, 13)
	assert_equal 0, local_date_time <=> "2025-01-13T10:00:00"
	assert_equal 0, local_date_time <=> zoned
	assert_equal(0, local_date_time <=> Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10))
	assert_equal(1, local_date_time <=> Literal::PlainDateTime.new(year: 2025, month: 1, day: 12, hour: 10))
	assert_equal(-1, Literal::PlainDateTime.new(year: 2025, month: 1, day: 12, hour: 10) <=> local_date_time)
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10), local_date_time
	assert_equal local_date_time, [Time.new(2025, 1, 13, 10, 0, 0, 0)].map(&Literal::PlainDateTime).first
	assert_equal 3_600, local_date_time.since(Time.new(2025, 1, 13, 9, 0, 0, 0)).seconds
	assert_equal 3_600, local_date_time.until(local_date_time + Literal::DatePeriod.new(hours: 1)).seconds
	range = (Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 0))..(Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 23))
	assert range === local_date_time
	assert range === "2025-01-13T10:00:00"
	assert_equal "2025-01-13T10:00:00", local_date_time.round(unit: :hour).iso8601
	assert_equal "2025-01-14T00:00:00", local_date_time.round(unit: :hour, increment: 24).iso8601
	assert_raises(ArgumentError) { local_date_time + 1 }
	assert_raises(ArgumentError) { local_date_time - 1 }
end
