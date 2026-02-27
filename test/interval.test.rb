# frozen_string_literal: true

test "interval validates and computes duration" do
	from = Literal::Instant.parse("2025-01-13T20:00:00Z")
	to = Literal::Instant.parse("2025-01-13T20:00:01.500000000Z")
	interval = Literal::Interval.new(from:, to:)

	assert_equal from, interval.from
	assert_equal to, interval.to
	assert_equal Literal::Duration.new(seconds: 1, subseconds: Rational(1, 2)), interval.duration
	assert_raises(ArgumentError) { Literal::Interval.new(from: to, to: from) }
end
