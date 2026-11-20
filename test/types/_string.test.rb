# frozen_string_literal: true

class StringTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _String(_Interface(:to_s)) === "string"
		assert _String(size: 6) === "string"

		refute _String(_Interface(:non_existing_method)) === "string"
		refute _String(size: 5) === "string"
	end
end
