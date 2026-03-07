# frozen_string_literal: true

test "iso8601 ordinal date formatting" do
	node = Literal::ISO8601::OrdinalDate.new(year: 2025, day_of_year: 13)
	invalid = Literal::ISO8601::OrdinalDate.new(year: 2025, day_of_year: 366)

	assert_equal node.iso8601, "2025-013"
	assert_equal node.to_s, "2025-013"
	assert node.valid?
	refute invalid.valid?
end
