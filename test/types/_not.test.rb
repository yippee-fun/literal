# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Not(Integer) === "string"
	assert _Not(_Array(Integer)) === [1, "2", 3]
	assert _Array(_Not(Integer)) === ["2"]

	refute _Not(Integer) === 18
	refute _Not(_Array(Integer)) === []
	refute _Not(_Array(Integer)) === [2]
	refute _Array(_Not(Integer)) === [1, "2"]
end

test "hierarchy" do
	assert_subtype _Not(Integer), _Not(Integer)
	assert_subtype _Not(Integer), _Not(Numeric)
	assert_subtype _Constraint(_Not(Integer), String), _Not(Integer)
	assert_subtype _Intersection(_Not(Integer), String), _Not(Integer)

	refute_subtype _Constraint(Integer, String), _Not(Integer)
	refute_subtype _Intersection(Integer, String), _Not(Integer)
end

test "error message" do
	error = assert_raises Literal::TypeError do
		Literal.check(18, _Not(Integer))
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		  Expected: _Not(Integer)
		  Actual (Integer): 18
	MSG
end
