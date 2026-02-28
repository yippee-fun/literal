# frozen_string_literal: true

test "iso8601 repeating interval formatting and interval typing" do
	interval = Literal::ISO8601::IntervalStartDuration.new(
		start: Literal::ISO8601::CalendarDate.new(year: 2025, month: 1, day: 13),
		duration: Literal::ISO8601::Duration.new(components: [Literal::ISO8601::DurationComponent.new(unit: :days, value: 1)]),
	)

	finite = Literal::ISO8601::RepeatingInterval.new(repetitions: 3, interval:)
	unbounded = Literal::ISO8601::RepeatingInterval.new(interval:)
	invalid = Literal::ISO8601::RepeatingInterval.new(repetitions: -2, interval:)

	assert_equal finite.iso8601, "R3/2025-01-13/P1D"
	assert_equal unbounded.iso8601, "R/2025-01-13/P1D"
	assert finite.valid?
	assert unbounded.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::RepeatingInterval.new(interval: Object.new) }
end
