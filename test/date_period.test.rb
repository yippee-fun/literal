# frozen_string_literal: true

test "date period normalization and arithmetic" do
	period = Literal::DatePeriod.new(
		centuries: 4,
		years: 1,
		months: 2,
		fortnights: 1,
		weeks: 1,
		days: 1,
		hours: 1,
		minutes: 61,
		seconds: 2,
		milliseconds: 3,
		microseconds: 4,
		nanoseconds: 5
	)

	assert_equal 4_814, period.months
	assert_equal 22, period.days
	assert_equal 2, period.hours
	assert_equal 62_003_004_005, period.nanoseconds

	summed = period + Literal::DatePeriod.new(months: 1, days: 2, hours: 3, nanoseconds: 4)
	assert_equal Literal::DatePeriod.new(months: 4_815, days: 24, hours: 5, nanoseconds: 62_003_004_009), summed

	diff = period - Literal::DatePeriod.new(months: 1, days: 2, hours: 3, nanoseconds: 4)
	assert_equal Literal::DatePeriod.new(months: 4_813, days: 20, hours: -1, nanoseconds: 62_003_004_001), diff

	assert_equal Literal::DatePeriod.new(months: -4_814, days: -22, hours: -2, nanoseconds: -62_003_004_005), -period
	assert period.equals(period.with)
end

test "date period include and cover" do
	period = Literal::DatePeriod.new(months: 6, days: 12, hours: 18, nanoseconds: 24)
	date = Literal::LocalDate.new(year: 1970, month: 1, day: 12)
	time = Literal::LocalTime.new(hour: 18)
	date_time = Literal::LocalDateTime.new(year: 1970, month: 1, day: 12, hour: 18)
	zoned_date_time = Literal::Instant.parse("1970-01-12T18:00:00Z").in_zone("UTC")

	assert period.include?(Literal::DatePeriod.new(months: 3, days: 6, hours: 9, nanoseconds: 12))
	assert period.cover?(Literal::DatePeriod.new(months: 6, days: 12, hours: 18, nanoseconds: 24))
	assert period.cover?(Literal::DatePeriod.new(months: 1, days: 2, hours: 3, nanoseconds: 5))
	assert period.cover?(date)
	assert period.cover?(Date.new(1970, 1, 12))
	assert period.cover?(time)
	assert period.cover?(date_time)
	assert period.cover?(zoned_date_time)
	assert period.cover?("1970-01-12T18:00:00")
	refute period.include?(Literal::DatePeriod.new(months: 1, days: 2, hours: 3, nanoseconds: 5))
	refute period.include?(date)
	refute period.include?(Literal::DatePeriod.new(months: 7, days: 2, hours: 3, nanoseconds: 5))
	refute period.include?(Literal::DatePeriod.new(months: -1, days: 2, hours: 3, nanoseconds: 5))
	refute period.include?("P1D")

	negative = Literal::DatePeriod.new(months: -6, days: -12, hours: -18, nanoseconds: -24)
	assert negative.include?(Literal::DatePeriod.new(months: -3, days: -6, hours: -9, nanoseconds: -12))
	assert negative.cover?(Literal::DatePeriod.new(months: -1, days: -2, hours: -3, nanoseconds: -5))
	refute negative.include?(Literal::DatePeriod.new(months: -1, days: -2, hours: -3, nanoseconds: -5))
	refute negative.include?(Literal::DatePeriod.new(months: 1, days: -2, hours: -3, nanoseconds: -5))
end

test "date period ago and from_now" do
	period = Literal::DatePeriod.new(days: 1)
	zone = Literal::FixedOffsetTimeZone.parse("UTC+00:00")

	from_now = period.from_now(zone)
	ago = period.ago("UTC+00:00")

	assert Literal::ZonedDateTime === from_now
	assert Literal::ZonedDateTime === ago
	assert_equal "UTC+00:00", from_now.zone
	assert_equal "UTC+00:00", ago.zone
	assert from_now.to_instant > zone.now.to_instant
	assert ago.to_instant < zone.now.to_instant
	assert_raises(ArgumentError) { period.from_now(123) }
	assert_raises(ArgumentError) { period.ago(123) }
end
