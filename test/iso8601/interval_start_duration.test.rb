# frozen_string_literal: true

test "iso8601 start duration interval formatting" do
	node = Literal::ISO8601::IntervalStartDuration.new(
		start: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 13),
		duration: Literal::ISO8601::Duration.new(components: [Literal::ISO8601::DurationComponent.new(unit: :days, value: 1)]),
	)
	invalid = Literal::ISO8601::IntervalStartDuration.new(
		start: Literal::ISO8601::CalendarDate.new(year: 2025, month: 2, day: 29),
		duration: Literal::ISO8601::Duration.new(components: [Literal::ISO8601::DurationComponent.new(unit: :days, value: 1)]),
	)

	assert_equal node.iso8601, "2025-01-13/P1D"
	assert node.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::IntervalStartDuration.new(start: Object.new, duration: node.duration) }
end
