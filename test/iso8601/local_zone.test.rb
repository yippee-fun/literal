# frozen_string_literal: true

test "iso8601 local zone formatting" do
	node = Literal::ISO8601::LocalZone.new

	assert_equal node.iso8601, ""
	assert_equal node.to_s, ""
	assert node.valid?
end
