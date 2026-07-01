# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Instance(Date) === Date.new(2025, 1, 13)

	refute _Instance(Date) === DateTime.new(2025, 1, 13)
	refute _Instance(Date) === "2025-01-13"
end

test "hierarchy" do
	assert_subtype _Instance(Date), _Instance(Date)

	refute_subtype _Instance(DateTime), _Instance(Date)
	refute_subtype DateTime, _Instance(Date)
end
