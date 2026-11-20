# frozen_string_literal: true

class ArrayTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Array(String) === []
		assert _Array(String) === ["a", "b", "c"]

		refute _Array(String) === ["a", "b", 42]
	end

	test "inline constraints" do
		type = _Array(String, length: 1..)

		assert type === ["a"]
		refute type === []
		refute type === [1]

		assert_equal type, _Constraint(_Array(String), length: 1..)
		assert_equal _Array(String, Array), _Constraint(_Array(String), Array)
		assert_equal _Array(String), Literal::Types::ArrayType.new(String)
	end
end
