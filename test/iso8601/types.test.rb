# frozen_string_literal: true

test "iso8601 string types distinguish parseable and valid forms" do
	assert Literal::ISO8601::ISO8601String === "2025-01-13"
	assert Literal::ISO8601::DateString === "2025-01-13"
	assert Literal::ISO8601::ValidDateString === "2024-02-29"

	refute Literal::ISO8601::DateString === "nope"
	refute Literal::ISO8601::ValidDateString === "2025-02-29"
	refute Literal::ISO8601::ISO8601String === 123
end

test "iso8601 typed string predicates work by shape" do
	assert Literal::ISO8601::TimeString === "10:15:30Z"
	assert Literal::ISO8601::DateTimeString === "2025-01-13T10:15:30Z"
	assert Literal::ISO8601::DurationString === "P1DT2H"
	assert Literal::ISO8601::IntervalString === "2025-01-13/P1D"

	refute Literal::ISO8601::TimeString === "2025-01-13"
	refute Literal::ISO8601::DateTimeString === "2025-01-13"
	refute Literal::ISO8601::DurationString === "2025-01-13"
	refute Literal::ISO8601::IntervalString === "2025-01-13"
end

test "iso8601 valid node predicate validates node semantics" do
	assert Literal::ISO8601::ValidNode === Literal::ISO8601.parse("2024-02-29")

	refute Literal::ISO8601::ValidNode === Literal::ISO8601.parse("nope")
	refute Literal::ISO8601::ValidNode === Literal::ISO8601.parse_date("2025-02-29")
end
