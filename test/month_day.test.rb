# frozen_string_literal: true

test "month day parse and validation" do
	month_day = Literal::MonthDay.parse("--02-29")

	assert_equal "--02-29", month_day.iso8601
	assert_equal month_day.iso8601, month_day.to_s
	assert_equal Literal::PlainDate.new(year: 2024, month: 2, day: 29), month_day.in_year(2024)
	assert_equal(-1, Literal::MonthDay.new(month: 2, day: 28) <=> month_day)
	assert_equal Literal::PlainDate.new(year: 2025, month: 2, day: 28), Literal::MonthDay.parse("--02-28").in_year(2025)
	assert_raises(ArgumentError) { Literal::MonthDay.parse("02-29") }
	assert_raises(Literal::TypeError) { Literal::MonthDay.parse("--13-01") }
	assert_raises(ArgumentError) { Literal::MonthDay.new(month: 2, day: 30) }
end
