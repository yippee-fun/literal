# frozen_string_literal: true

test "iso8601 duration end interval formatting" do
	node = Literal::ISO8601::IntervalDurationEnd.new(
		duration: Literal::ISO8601::Duration.new(components: [Literal::ISO8601::DurationComponent.new(unit: :days, value: 1)]),
		ending: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 14),
	)
	invalid = Literal::ISO8601::IntervalDurationEnd.new(
		duration: Literal::ISO8601::Duration.new(components: [Literal::ISO8601::DurationComponent.new(unit: :weeks, value: 1), Literal::ISO8601::DurationComponent.new(unit: :days, value: 1)]),
		ending: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 14),
	)

	assert_equal node.iso8601, "P1D/2025-01-14"
	assert node.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::IntervalDurationEnd.new(duration: node.duration, ending: Object.new) }
end
