# frozen_string_literal: true

class LambdaTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Lambda === -> {}
		assert _Lambda === -> (arg) { arg }
		assert _Lambda === lambda {}

		refute _Lambda === proc {}
	end
end
