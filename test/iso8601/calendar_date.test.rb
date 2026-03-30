# frozen_string_literal: true

test "iso8601 calendar date formatting" do
	node = Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 13)
	invalid = Literal::ISO8601::CalendarDate.new(year: 2025, month: 2, day: 29)

	assert_equal node.iso8601, "2025-01-13"
	assert_equal node.to_s, "2025-01-13"
	assert node.valid?
	refute invalid.valid?
end
