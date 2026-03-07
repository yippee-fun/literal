# frozen_string_literal: true

test "iso8601 date time formatting and date typing" do
	node = Literal::ISO8601::DateTime.new(
		date: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 13),
		time: Literal::ISO8601::TimeOfDay.new(hour: 10, minute: 15, second: 30, precision: :second, zone: Literal::ISO8601::UTCZone.new),
	)
	invalid = Literal::ISO8601::DateTime.new(
		date: Literal::ISO8601::CalendarDate.new(year: 2025, month: 2, day: 29),
		time: Literal::ISO8601::TimeOfDay.new(hour: 10, precision: :hour, zone: Literal::ISO8601::LocalZone.new),
	)

	assert_equal node.iso8601, "2025-01-13T10:15:30Z"
	assert_equal node.to_s, "2025-01-13T10:15:30Z"
	assert node.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::DateTime.new(date: Object.new, time: node.time) }
end
