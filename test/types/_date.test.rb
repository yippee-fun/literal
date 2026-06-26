# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Date(_Interface(:to_date)) === Date.today
	assert _Date(Date.today) === Date.today
	assert _Date((Date.today)..) === Date.today + 1

	refute _Date(_Interface(:non_existing_method)) === Date.today
	refute _Date(Date.today) === "2025-01-13"
	refute _Date(Date.today) === nil
	refute _Date((Date.today)..) === Date.today - 1

	assert _Date(year: 2025) === Date.new(2025, 1, 13)
	refute _Date(year: 2025) === Date.new(2024, 1, 13)

	refute _Date(DateTime, _Interface(:to_datetime)) === DateTime.now
	refute _Date(DateTime, year: 2025) === DateTime.new(2025, 1, 13)
	refute _Date(DateTime, year: 2025) === Date.new(2025, 1, 13)
end
