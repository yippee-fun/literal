# frozen_string_literal: true

test "iso8601 duration component formatting and unit typing" do
	seconds = Literal::ISO8601::DurationComponent.new(unit: :seconds, value: 6, fraction: 7, fraction_digits: 1)
	months = Literal::ISO8601::DurationComponent.new(unit: :months, value: 2)
	invalid_fraction = Literal::ISO8601::DurationComponent.new(unit: :seconds, value: 1, fraction: 10, fraction_digits: 1)

	assert_equal seconds.iso8601, "6.7S"
	assert_equal months.iso8601, "2M"
	assert seconds.valid?
	assert months.valid?
	refute invalid_fraction.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::DurationComponent.new(unit: :millis, value: 1) }
end
