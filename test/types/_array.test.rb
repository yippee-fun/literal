# frozen_string_literal: true

class ArrayTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Array(String) === []
		assert _Array(String) === ["a", "b", "c"]

		refute _Array(String) === ["a", "b", 42]
	end
end
