# frozen_string_literal: true

include Literal::Types

test "=== with object constraints" do
	age_constraint = _Constraint(Integer, 18..)

	assert age_constraint === 18

	refute age_constraint === 17
	refute age_constraint === 17.5
end

test "hierarchy" do
	assert_subtype _Constraint(String), _Constraint(String)
	assert_subtype _Constraint(_Array(Array)), _Constraint(_Array(Enumerable))
	assert_subtype _Constraint(Array, size: 1..5), _Constraint(Array, size: 1..5)
	assert_subtype _Constraint(Array, size: 1..2), _Constraint(Array, size: 1..3)
	assert_subtype _Intersection(Array), _Constraint(Enumerable, Array)
	assert_subtype _Constraint(_Array(Enumerable), name: _String(size: 1..5)), _Constraint(_Array(Enumerable), name: _String(size: 1..5))

	refute_subtype _Constraint(Array, size: 1..3), _Constraint(Array, size: 1..2)
	refute_subtype _Constraint(String, size: 1), _Constraint(String, size: 4)

	assert_subtype _Constraint(Integer, 1..), Integer
	refute_subtype _Constraint(Integer, 1..), Float
end

test "error message with object constraints" do
	error = assert_raises Literal::TypeError do
		Literal.check(17, _Constraint(Integer, 18..))
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    _Constraint(Integer, 18..)
		      Expected: 18..
		      Actual (Integer): 17
	MSG
end

test "=== with property constraints" do
	age_constraint = _Constraint(Array, size: 2..3)

	assert age_constraint === [1, 2]
	assert age_constraint === [1, 2, 3]

	refute age_constraint === [1]
	refute age_constraint === [1, 2, 3, 4]
	refute age_constraint === Set[1, 2]
end
