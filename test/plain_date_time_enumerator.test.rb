# frozen_string_literal: true

test "local date time enumerator normalizes units and builds interval" do
	enumerator = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
		to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 14, hour: 10),
		unit: :day,
		step: 1
	)

	assert_equal :days, enumerator.unit
	assert_equal Literal::DatePeriod.new(days: 1), enumerator.interval
	assert_raises(ArgumentError) do
		Literal::PlainDateTimeEnumerator.new(
			from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
			to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 14, hour: 10),
			unit: :day,
			step: 0
		)
	end
end

test "local date time enumerator yields ascending values" do
	enumerator = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
		to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 14),
		unit: :hour,
		step: 2
	)

	values = []
	enumerator.each { |value| values << value }

	assert_equal [10, 12, 14], values.map(&:hour)
	assert Enumerator === enumerator.each
	assert_equal 3, enumerator.each.count
	assert_equal 3, enumerator.each.size
	assert_equal nil, enumerator.each { |_value| :ok }
end

test "local date time enumerator yields descending values" do
	enumerator = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 14),
		to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
		unit: :hours,
		step: -2
	)

	assert_equal [14, 12, 10], enumerator.each.map(&:hour)
	assert_equal 3, enumerator.each.size
end

test "local date time enumerator returns empty when direction does not reach endpoint" do
	forward = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 14),
		to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
		unit: :hours,
		step: 1
	)

	backward = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10),
		to: Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 14),
		unit: :hours,
		step: -1
	)

	assert_equal 0, forward.each.count
	assert_equal 0, backward.each.count
	assert_equal 0, forward.each.size
	assert_equal 0, backward.each.size
end

test "local date time enumerator month stepping works with calendar durations" do
	enumerator = Literal::PlainDateTimeEnumerator.new(
		from: Literal::PlainDateTime.new(year: 2025, month: 1, day: 1, hour: 0),
		to: Literal::PlainDateTime.new(year: 2025, month: 4, day: 1, hour: 0),
		unit: :month,
		step: 1
	)

	assert_equal [1, 2, 3, 4], enumerator.each.map(&:month)
	assert_equal nil, enumerator.each.size
end
