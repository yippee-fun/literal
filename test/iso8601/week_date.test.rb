# frozen_string_literal: true

test "iso8601 week date formatting" do
	with_day = Literal::ISO8601::WeekDate.new(year: 2025, week: 3, weekday: 1)
	without_day = Literal::ISO8601::WeekDate.new(year: 2025, week: 3)
	invalid_week = Literal::ISO8601::WeekDate.new(year: 2021, week: 53, weekday: 1)
	invalid_weekday = Literal::ISO8601::WeekDate.new(year: 2025, week: 3, weekday: 8)

	assert_equal with_day.iso8601, "2025-W03-1"
	assert_equal without_day.iso8601, "2025-W03"
	assert with_day.valid?
	assert without_day.valid?
	refute invalid_week.valid?
	refute invalid_weekday.valid?
end
