# frozen_string_literal: true

test "iso8601 utc zone formatting" do
	node = Literal::ISO8601::UTCZone.new

	assert_equal node.iso8601, "Z"
	assert_equal node.to_s, "Z"
	assert node.valid?
end
