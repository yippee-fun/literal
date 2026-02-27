# frozen_string_literal: true

test "local date time range overlap and interval conversion" do
	from = Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 10)
	to = Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 12)
	range = Literal::LocalDateTimeRange.new(from:, to:)

	other = Literal::LocalDateTimeRange.new(
		from: Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 11),
		to: Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 13)
	)

	assert range.include?(Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 11))
	assert range.cover?(Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 11))
	refute range.include?("2025-01-13T11:00:00")
	assert range.overlaps?(other)
	assert_equal(-1, range <=> other)
	assert_equal(0, range <=> Literal::LocalDateTimeRange.new(from:, to:))
	assert_equal(1, other <=> range)
	assert_equal "2025-01-13T10:00:00..2025-01-13T12:00:00", range.to_s
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 11), range.intersection(other).from
	assert_equal nil, range.intersection(
		Literal::LocalDateTimeRange.new(
			from: Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 13),
			to: Literal::LocalDateTime.new(year: 2025, month: 1, day: 13, hour: 14)
		)
	)
	assert_equal Literal::Duration.new(nanoseconds: 7_200_000_000_000), range.in_zone("UTC").duration
	assert_raises(ArgumentError) { Literal::LocalDateTimeRange.new(from: to, to: from) }
end
