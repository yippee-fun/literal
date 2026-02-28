# frozen_string_literal: true

test "iso8601 parser normalizes supported forms" do
	assert_equal Literal::ISO8601.parse("20250113").iso8601, "2025-01-13"
	assert_equal Literal::ISO8601.parse("2025-013").iso8601, "2025-013"
	assert_equal Literal::ISO8601.parse("2025W031").iso8601, "2025-W03-1"
	assert_equal Literal::ISO8601.parse("101530,25+0130").iso8601, "10:15:30.25+01:30"
	assert_equal Literal::ISO8601.parse("20250113T101530Z").iso8601, "2025-01-13T10:15:30Z"
	assert_equal Literal::ISO8601.parse("P1Y2M3DT4H5M6,7S").iso8601, "P1Y2M3DT4H5M6.7S"
	assert_equal Literal::ISO8601.parse("20250113/P1D").iso8601, "2025-01-13/P1D"
	assert_equal Literal::ISO8601.parse("R3/20250113/P1D").iso8601, "R3/2025-01-13/P1D"
end

test "iso8601 specific parser methods enforce shapes" do
	assert Literal::ISO8601::CalendarDate === Literal::ISO8601.parse_date("2025-01-13")
	assert Literal::ISO8601::TimeOfDay === Literal::ISO8601.parse_time("10:15:30Z")
	assert Literal::ISO8601::DateTime === Literal::ISO8601.parse_date_time("2025-01-13T10:15:30Z")
	assert Literal::ISO8601::Duration === Literal::ISO8601.parse_duration("P1DT2H")
	assert Literal::ISO8601::IntervalStartDuration === Literal::ISO8601.parse_interval("2025-01-13/P1D")

	assert Literal::ISO8601::Error === Literal::ISO8601.parse_date("2025-01-13T10:15:30Z")
	assert Literal::ISO8601::Error === Literal::ISO8601.parse_time("2025-01-13")
	assert Literal::ISO8601::Error === Literal::ISO8601.parse_date_time("2025-01-13")
	assert Literal::ISO8601::Error === Literal::ISO8601.parse_duration("2025-01-13")
	assert Literal::ISO8601::Error === Literal::ISO8601.parse_interval("2025-01-13")
end

test "iso8601 parser keeps syntax and semantic validation separate" do
	invalid_date = Literal::ISO8601.parse_date("2025-02-29")
	invalid_time = Literal::ISO8601.parse_time("24")

	refute invalid_date.valid?
	refute invalid_time.valid?
end
