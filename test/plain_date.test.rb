# frozen_string_literal: true

test "local date parse and class helper" do
	assert_equal 5, Literal::Temporal.zellers_congruence(year: 2024, month: 2, day: 29)

	local_date = Literal::PlainDate.parse("2024-02-29")
	assert_equal 2024, local_date.year
	assert_equal 2, local_date.month
	assert_equal 29, local_date.day
	assert_raises(ArgumentError) { Literal::PlainDate.parse("2024/02/29") }
end

test "local date names, weekdays and conversions" do
	date = Literal::PlainDate.new(year: 2024, month: 2, day: 29)

	assert_equal "Thursday", date.name
	assert_equal "Thu", date.short_name
	assert_equal 60, date.day_of_year
	assert_equal 29, date.day_of_month
	assert_equal 4, date.day_of_week
	refute date.monday?
	refute date.tuesday?
	refute date.wednesday?
	assert date.thursday?
	refute date.friday?
	refute date.saturday?
	refute date.sunday?
	refute date.weekend?
	assert date.weekday?

	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 2), date.to_year_month
	assert_equal Date.new(2024, 2, 29), date.to_date
	assert_equal Literal::MonthDay.new(month: 2, day: 29), date.to_month_day
	assert_equal Literal::PlainYear.new(year: 2024), date.to_year
	assert_equal "2024-02-29", date.iso8601
	assert_equal date.iso8601, date.to_s
	assert_equal Literal::PlainDate.new(year: 2024, month: 2, day: 29), date
	assert_equal(-1, Literal::PlainDate.new(year: 2024, month: 2, day: 28) <=> date)
	assert_equal Literal::DatePeriod.new(days: 1), date.since(Literal::PlainDate.new(year: 2024, month: 2, day: 28))
	assert_equal Literal::DatePeriod.new(days: 1), Literal::PlainDate.new(year: 2024, month: 3, day: 1).until(Literal::PlainDate.new(year: 2024, month: 3, day: 2))

	range = (Literal::PlainDate.new(year: 2024, month: 2, day: 1))..(Literal::PlainDate.new(year: 2024, month: 2, day: 29))
	assert range === date
	refute range === "2024-02-29"
end

test "local date day navigation and day-of-week navigation" do
	date = Literal::PlainDate.new(year: 2025, month: 1, day: 13)

	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 14), date.next_day
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 14), date.succ
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 12), date.prev_day
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 12), date.pred

	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 20), date.next_monday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 14), date.next_tuesday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 15), date.next_wednesday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 16), date.next_thursday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 17), date.next_friday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 18), date.next_saturday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 19), date.next_sunday

	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 6), date.prev_monday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 7), date.prev_tuesday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 8), date.prev_wednesday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 9), date.prev_thursday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 10), date.prev_friday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 11), date.prev_saturday
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 12), date.prev_sunday
end

test "local date date-time construction, arithmetic and enumeration" do
	date = Literal::PlainDate.new(year: 2025, month: 1, day: 13)
	time = Literal::PlainTime.new(hour: 9, minute: 30)
	zoned = Literal::Instant.parse("2025-01-13T09:30:00Z").in_zone("UTC")

	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 30), date.at(time)
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 30), date.at(hour: 9, minute: 30)
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 30), date.at("09:30")
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 30), date.at(Time.new(2025, 1, 13, 9, 30, 0, 0))
	assert_equal Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 9, minute: 30), date.at(zoned)
	assert_raises(ArgumentError) { date.at(time, hour: 10) }
	assert_equal date, [Date.new(2025, 1, 13)].map(&Literal::PlainDate).first
	assert_equal Literal::DatePeriod.new(days: 1), date.since(Date.new(2025, 1, 12))
	assert_equal Literal::DatePeriod.new(days: 1), date.until("2025-01-14")

	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 15), date + Literal::DatePeriod.new(days: 2)
	assert_equal date, date - Literal::DatePeriod.new(days: 0)
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 11), date - Literal::DatePeriod.new(days: 2)
	assert_raises(ArgumentError) { date + Literal::DatePeriod.new(hours: 1) }
	assert_raises(ArgumentError) { date + 1 }
	assert_raises(ArgumentError) { date - 1 }

	hours = []
	date.each_hour do |value|
		hours << value.hour
		break if hours.length == 3
	end
	assert_equal [0, 1, 2], hours
	assert_equal 24, date.each_hour.count

	minutes = []
	date.each_minute do |value|
		minutes << [value.hour, value.minute]
		break if minutes.length == 3
	end
	assert_equal [[0, 0], [0, 1], [0, 2]], minutes
	assert_equal 1_440, date.each_minute.count

	seconds = []
	date.each_second do |value|
		seconds << [value.hour, value.minute, value.second]
		break if seconds.length == 3
	end
	assert_equal [[0, 0, 0], [0, 0, 1], [0, 0, 2]], seconds
	assert_equal 86_400, date.each_second.count
end
