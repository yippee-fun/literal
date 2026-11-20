# frozen_string_literal: true

class FloatTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Float(18.0..) === 18.0
		assert _Float(18.0..) === 19.5

		refute _Float(18.0..) === 17.99
		refute _Float(18.0..) === 42
		refute _Float(18.0..) === "string"
		refute _Float(18.0..) === nil
	end
end
