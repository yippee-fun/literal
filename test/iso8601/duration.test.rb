# frozen_string_literal: true

test "iso8601 duration formatting and sign typing" do
	node = Literal::ISO8601::Duration.new(
		sign: -1,
		components: [
			Literal::ISO8601::DurationComponent.new(unit: :years, value: 1),
			Literal::ISO8601::DurationComponent.new(unit: :months, value: 2),
			Literal::ISO8601::DurationComponent.new(unit: :days, value: 3),
			Literal::ISO8601::DurationComponent.new(unit: :hours, value: 4),
			Literal::ISO8601::DurationComponent.new(unit: :minutes, value: 5),
			Literal::ISO8601::DurationComponent.new(unit: :seconds, value: 6, fraction: 7, fraction_digits: 1),
		],
	)
	invalid_weeks = Literal::ISO8601::Duration.new(
		components: [
			Literal::ISO8601::DurationComponent.new(unit: :weeks, value: 1),
			Literal::ISO8601::DurationComponent.new(unit: :days, value: 1),
		],
	)
	invalid_fraction_position = Literal::ISO8601::Duration.new(
		components: [
			Literal::ISO8601::DurationComponent.new(unit: :seconds, value: 1, fraction: 5, fraction_digits: 1),
			Literal::ISO8601::DurationComponent.new(unit: :minutes, value: 1),
		],
	)

	assert_equal node.iso8601, "-P1Y2M3DT4H5M6.7S"
	assert_equal node.to_s, "-P1Y2M3DT4H5M6.7S"
	assert node.valid?
	refute invalid_weeks.valid?
	refute invalid_fraction_position.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::Duration.new(sign: 0, components: []) }
end
