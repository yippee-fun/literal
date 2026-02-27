# frozen_string_literal: true

test "local year class helpers" do
	assert_equal 366, Literal::LocalYear.days_in_year(2024)
	assert_equal 365, Literal::LocalYear.days_in_year(2025)
	assert Literal::LocalYear.leap_year?(2024)
	refute Literal::LocalYear.leap_year?(2025)
	assert_equal(-1, Literal::LocalYear.compare(Literal::LocalYear.new(year: 2024), Literal::LocalYear.new(year: 2025)))
end

test "local year navigation, ranges and conversions" do
	year = Literal::LocalYear.new(year: 2024)

	assert_equal Literal::LocalYear.new(year: 2025), year.next_year
	assert_equal Literal::LocalYear.new(year: 2025), year.succ
	assert_equal Literal::LocalYear.new(year: 2023), year.prev_year
	assert_equal Literal::LocalYear.new(year: 2023), year.pred
	assert_equal(-1, year <=> Literal::LocalYear.new(year: 2025))
	assert_equal(0, year <=> Literal::LocalYear.new(year: 2024))
	assert_equal(1, year <=> Literal::LocalYear.new(year: 2023))
	assert_raises(ArgumentError) { year <=> "2024" }

	assert_equal Literal::LocalMonth.new(year: 2024, month: 1), year.first_month
	assert_equal Literal::LocalMonth.new(year: 2024, month: 12), year.last_month
	assert_equal Literal::LocalDate.new(year: 2024, month: 1, day: 1), year.first_day
	assert_equal Literal::LocalDate.new(year: 2024, month: 12, day: 31), year.last_day
	assert_equal (year.first_month)..(year.last_month), year.months
	assert_equal Literal::LocalMonth.new(year: 2024, month: 9), year.month(9)
	assert_equal Literal::YearMonth.new(year: 2024, month: 9), year.year_month(9)

	months = []
	year.each_month { |month| months << month.month }
	assert_equal (1..12).to_a, months

	enumerator = year.each_month
	assert Enumerator === enumerator
	assert_equal 12, enumerator.count

	days = year.each_day
	assert Enumerator === days
	assert_equal 366, days.count
	assert_equal Literal::LocalDate.new(year: 2024, month: 1, day: 1), days.first
	assert_equal Literal::LocalDate.new(year: 2024, month: 12, day: 31), days.to_a.last
end

test "local year named months and predicates" do
	year = Literal::LocalYear.new(year: 2024)

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
	assert year.equals(year.with)

	bce = Literal::LocalYear.new(year: -1)
	refute bce.ce?
	assert bce.bce?
end
