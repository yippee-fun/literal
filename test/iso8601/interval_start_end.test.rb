# frozen_string_literal: true

test "iso8601 start end interval formatting" do
	node = Literal::ISO8601::IntervalStartEnd.new(
		start: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 13),
		ending: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 14),
	)
	invalid = Literal::ISO8601::IntervalStartEnd.new(
		start: Literal::ISO8601::CalendarDate.new(year: 2025, month: 2, day: 29),
		ending: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 14),
	)

	assert_equal node.iso8601, "2025-01-13/2025-01-14"
	assert node.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::IntervalStartEnd.new(start: Object.new, ending: node.ending) }
end
