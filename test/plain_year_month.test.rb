# frozen_string_literal: true

test "plain year month parse" do
	month = Literal::PlainYearMonth.parse("2025-01")

	assert_equal "2025-01", month.iso8601
	assert_equal month.iso8601, month.to_s
	assert_equal Literal::PlainDate.new(year: 2025, month: 1, day: 13), month.at_day(13)
	assert_equal(-1, Literal::PlainYearMonth.new(year: 2024, month: 12) <=> month)
end

test "plain year month class helper" do
	assert_equal 29, Literal::PlainYearMonth.days_in_month(year: 2024, month: 2)
	assert_equal 28, Literal::PlainYearMonth.days_in_month(year: 2025, month: 2)
	assert_equal 30, Literal::PlainYearMonth.days_in_month(year: 2025, month: 9)
	assert_equal(-1, Literal::PlainYearMonth.new(year: 2024, month: 1) <=> Literal::PlainYearMonth.new(year: 2024, month: 2))
end

test "plain year month navigation, comparison and conversion" do
	month = Literal::PlainYearMonth.new(year: 2024, month: 12)

	assert_equal Literal::PlainYearMonth.new(year: 2025, month: 1), month.next_month
	assert_equal Literal::PlainYearMonth.new(year: 2025, month: 1), month.succ
	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 11), month.prev_month
	assert_equal Literal::PlainYearMonth.new(year: 2024, month: 11), month.pred
	assert_equal(-1, Literal::PlainYearMonth.new(year: 2024, month: 11) <=> month)
	assert_equal(0, month <=> Literal::PlainYearMonth.new(year: 2024, month: 12))
	assert_equal(1, month <=> Literal::PlainYearMonth.new(year: 2023, month: 12))
	assert_equal nil, (month <=> "2024-12")

	assert_equal Literal::PlainYear.new(year: 2024), month.to_year
	assert_equal Literal::PlainDate.new(year: 2024, month: 12, day: 10), month.at_day(10)
	assert_equal "2024-12", month.iso8601
	assert_equal month.iso8601, month.to_s
end

test "plain year month names, predicates and day iteration" do
	february = Literal::PlainYearMonth.new(year: 2024, month: 2)

	assert_equal "February", february.name
	assert_equal "Feb", february.short_name
	assert_equal 29, february.number_of_days
	assert_equal (february.first_day)..(february.last_day), february.days

	days = []
	february.each_day { |day| days << day.day }
	assert_equal (1..29).to_a, days

	enumerator = february.each_day
	assert Enumerator === enumerator
	assert_equal 29, enumerator.count

	month = Literal::PlainYearMonth.new(year: 2024, month: 1)
	assert month.january?
	refute month.february?
	refute month.march?
	refute month.april?
	refute month.may?
	refute month.june?
	refute month.july?
	refute month.august?
	refute month.september?
	refute month.october?
	refute month.november?
	refute month.december?

	assert Literal::PlainYearMonth.new(year: 2024, month: 2).february?
	assert Literal::PlainYearMonth.new(year: 2024, month: 3).march?
	assert Literal::PlainYearMonth.new(year: 2024, month: 4).april?
	assert Literal::PlainYearMonth.new(year: 2024, month: 5).may?
	assert Literal::PlainYearMonth.new(year: 2024, month: 6).june?
	assert Literal::PlainYearMonth.new(year: 2024, month: 7).july?
	assert Literal::PlainYearMonth.new(year: 2024, month: 8).august?
	assert Literal::PlainYearMonth.new(year: 2024, month: 9).september?
	assert Literal::PlainYearMonth.new(year: 2024, month: 10).october?
	assert Literal::PlainYearMonth.new(year: 2024, month: 11).november?
	assert Literal::PlainYearMonth.new(year: 2024, month: 12).december?
end
