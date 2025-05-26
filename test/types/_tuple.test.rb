# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Tuple(String, Integer) === ["a", 1]
	assert _Tuple(Symbol, Float) === [:symbol, 3.14]

	refute _Tuple(String, Integer) === [1, "a"]
	refute _Tuple(String, Integer) === ["a", 1, 2]
	refute _Tuple(String, Integer) === ["a"]
	refute _Tuple(String, Integer) === nil
end

test "hierarchy" do
	assert_subtype _Tuple(String, Integer), _Tuple(String, Integer)

	refute_subtype _Tuple(String, Float), _Tuple(String, Integer)
end

test "error message" do
	error = assert_raises(Literal::TypeError) do
		Literal.check(
			[1, "a"],
			_Tuple(String, Integer),
		)
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		    [0]
		      Expected: String
		      Actual (Integer): 1
		    [1]
		      Expected: Integer
		      Actual (String): "a"
	ERROR
end
