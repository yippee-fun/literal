# frozen_string_literal: true

test "local year class helpers" do
	assert_equal 366, Literal::PlainYear.days_in_year(2024)
	assert_equal 365, Literal::PlainYear.days_in_year(2025)
	assert Literal::PlainYear.leap_year?(2024)
	refute Literal::PlainYear.leap_year?(2025)
	assert_equal(-1, Literal::PlainYear.new(year: 2024) <=> Literal::PlainYear.new(year: 2025))
end

test "local year navigation, ranges and conversions" do
	year = Literal::PlainYear.new(year: 2024)

	assert_equal Literal::PlainYear.new(year: 2025), year.next_year
	assert_equal Literal::PlainYear.new(year: 2025), year.succ
	assert_equal Literal::PlainYear.new(year: 2023), year.prev_year
	assert_equal Literal::PlainYear.new(year: 2023), year.pred
	assert_equal(-1, year <=> Literal::PlainYear.new(year: 2025))
	assert_equal(0, year <=> Literal::PlainYear.new(year: 2024))
	assert_equal(1, year <=> Literal::PlainYear.new(year: 2023))
	assert_equal nil, (year <=> "2024")

	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 1), year.first_month
	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 12), year.last_month
	assert_equal Literal::PlainDate.new(year: 2024, month: 1, day: 1), year.first_day
	assert_equal Literal::PlainDate.new(year: 2024, month: 12, day: 31), year.last_day
	assert_equal (year.first_month)..(year.last_month), year.months
	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 9), year.month(9)

	months = []
	year.each_month { |month| months << month.month }
	assert_equal (1..12).to_a, months

	enumerator = year.each_month
	assert Enumerator === enumerator
	assert_equal 12, enumerator.count

	days = year.each_day
	assert Enumerator === days
	assert_equal 366, days.count
	assert_equal Literal::PlainDate.new(year: 2024, month: 1, day: 1), days.first
	assert_equal Literal::PlainDate.new(year: 2024, month: 12, day: 31), days.to_a.last

	weeks = []
	year.each_week do |value|
		weeks << [value.month, value.day]
		break if weeks.length == 3
	end
	assert_equal [[1, 1], [1, 8], [1, 15]], weeks

	enumerator = year.each_week
	assert Enumerator === enumerator
	assert_equal 53, enumerator.count
	assert_equal Literal::PlainDate.new(year: 2024, month: 1, day: 1), enumerator.first
	assert_equal Literal::PlainDate.new(year: 2024, month: 12, day: 30), enumerator.to_a.last

	hours = []
	year.each_hour do |value|
		hours << [value.month, value.day, value.hour]
		break if hours.length == 3
	end
	assert_equal [[1, 1, 0], [1, 1, 1], [1, 1, 2]], hours

	enumerator = year.each_hour
	assert Enumerator === enumerator
	assert_equal 8_784, enumerator.count
	assert_equal Literal::PlainDateTime.new(year: 2024, month: 1, day: 1, hour: 0), enumerator.first
	assert_equal Literal::PlainDateTime.new(year: 2024, month: 12, day: 31, hour: 23), enumerator.to_a.last

	minutes = []
	year.each_minute do |value|
		minutes << [value.month, value.day, value.hour, value.minute]
		break if minutes.length == 3
	end
	assert_equal [[1, 1, 0, 0], [1, 1, 0, 1], [1, 1, 0, 2]], minutes

	enumerator = year.each_minute
	assert Enumerator === enumerator
	assert_equal 527_040, enumerator.count
	assert_equal Literal::PlainDateTime.new(year: 2024, month: 1, day: 1, hour: 0, minute: 0), enumerator.first
	assert_equal Literal::PlainDateTime.new(year: 2024, month: 12, day: 31, hour: 23, minute: 59), enumerator.to_a.last

	seconds = []
	year.each_second do |value|
		seconds << [value.month, value.day, value.hour, value.minute, value.second]
		break if seconds.length == 3
	end
	assert_equal [[1, 1, 0, 0, 0], [1, 1, 0, 0, 1], [1, 1, 0, 0, 2]], seconds

	enumerator = year.each_second
	assert Enumerator === enumerator
	assert_equal 31_622_400, enumerator.count
	assert_equal Literal::PlainDateTime.new(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0), enumerator.first
	rollover = year.each_second.drop(59).first
	assert_equal [0, 0, 59], [rollover.hour, rollover.minute, rollover.second]
	next_minute = year.each_second.drop(60).first
	assert_equal [0, 1, 0], [next_minute.hour, next_minute.minute, next_minute.second]
end

test "local year named months and predicates" do
	year = Literal::PlainYear.new(year: 2024)

	assert_equal 1, year.january.month
	assert_equal 2, year.february.month
	assert_equal 3, year.march.month
	assert_equal 4, year.april.month
	assert_equal 5, year.may.month
	assert_equal 6, year.june.month
	assert_equal 7, year.july.month
	assert_equal 8, year.august.month
	assert_equal 9, year.september.month
	assert_equal 10, year.october.month
	assert_equal 11, year.november.month
	assert_equal 12, year.december.month

	assert year.leap_year?
	assert year.ce?
	refute year.bce?
	assert_equal "2024", year.iso8601
	assert_equal year.iso8601, year.to_s

	bce = Literal::PlainYear.new(year: -1)
	refute bce.ce?
	assert bce.bce?
end
