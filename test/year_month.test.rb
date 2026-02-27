# frozen_string_literal: true

test "year month parse and helpers" do
	year_month = Literal::YearMonth.parse("2025-01")

	assert_equal "2025-01", year_month.iso8601
	assert_equal year_month.iso8601, year_month.to_s
	assert_equal Literal::LocalMonth.new(year: 2025, month: 1), year_month.to_local_month
	assert_equal Literal::LocalDate.new(year: 2025, month: 1, day: 13), year_month.at_day(13)
	assert year_month.equals(year_month.with)
	assert_equal(-1, Literal::YearMonth.compare(Literal::YearMonth.new(year: 2024, month: 12), year_month))
end
