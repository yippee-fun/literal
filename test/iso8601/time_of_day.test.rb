# frozen_string_literal: true

test "iso8601 time of day formatting" do
	hour = Literal::ISO8601::TimeOfDay.new(hour: 10, zone: Literal::ISO8601::LocalZone.new)
	minute = Literal::ISO8601::TimeOfDay.new(hour: 10, minute: 15, precision: :minute, zone: Literal::ISO8601::UTCZone.new)
	midnight = Literal::ISO8601::TimeOfDay.new(hour: 24, minute: 0, second: 0, precision: :second, zone: Literal::ISO8601::LocalZone.new)
	second_fraction = Literal::ISO8601::TimeOfDay.new(
		hour: 10,
		minute: 15,
		second: 30,
		precision: :second,
		fraction: 25,
		fraction_digits: 2,
		fraction_unit: :second,
		zone: Literal::ISO8601::OffsetZone.new(sign: 1, hours: 1, minutes: 30),
	)
	invalid_precision = Literal::ISO8601::TimeOfDay.new(hour: 10, minute: 15, precision: :hour, zone: Literal::ISO8601::LocalZone.new)
	invalid_fraction = Literal::ISO8601::TimeOfDay.new(
		hour: 10,
		minute: 15,
		second: 30,
		precision: :second,
		fraction: 1,
		fraction_digits: 0,
		fraction_unit: :none,
		zone: Literal::ISO8601::LocalZone.new,
	)

	assert_equal hour.iso8601, "10"
	assert_equal minute.iso8601, "10:15Z"
	assert_equal second_fraction.iso8601, "10:15:30.25+01:30"
	assert hour.valid?
	assert minute.valid?
	assert midnight.valid?
	assert second_fraction.valid?
	refute invalid_precision.valid?
	refute invalid_fraction.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::TimeOfDay.new(hour: 10, precision: :millisecond, zone: Literal::ISO8601::LocalZone.new) }
end
