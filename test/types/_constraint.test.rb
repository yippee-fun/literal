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
	assert_subtype Array, _Constraint(Enumerable, Array)
	assert_subtype _Intersection(Array), _Constraint(Enumerable, Array)
	assert_subtype _Constraint(_Array(Enumerable), name: _String(size: 1..5)), _Constraint(_Array(Enumerable), name: _String(size: 1..5))
	assert_subtype _Interface(:a, :b), _Constraint(_Interface(:a), _Interface(:b))
	assert_subtype _Interface(:a, :b, :c), _Constraint(_Interface(:a, :b), _Interface(:c))

	refute_subtype _Constraint(Array, size: 1..3), _Constraint(Array, size: 1..2)
	refute_subtype _Constraint(String, size: 1), _Constraint(String, size: 4)
	assert_subtype 3.14, _Float(finite?: _Truthy)
	refute_subtype Float::INFINITY, _Float(finite?: _Truthy)
	assert_subtype _Float(1..10), _Float(finite?: _Truthy)
	refute_subtype _Float(1..), _Float(finite?: _Truthy)
	refute_subtype _Float(..10), _Float(finite?: _Truthy)

	# finite? is a known boolean predicate on Numeric, so the exact-true and
	# truthy spellings denote the same floats. On an unbounded receiver,
	# finite? could return anything, so the fact doesn’t apply.
	assert_subtype _Float(finite?: true), _Float(finite?: _Truthy)
	assert_subtype _Float(finite?: _Truthy), _Float(finite?: true)
	refute_subtype _Float(finite?: _Boolean), _Float(finite?: true)
	refute_subtype _Constraint(Object, finite?: _Truthy), _Constraint(Object, finite?: true)
	assert_subtype 3.14, _Float(finite?: true)
	refute_subtype Float::INFINITY, _Float(finite?: true)
	assert_subtype _Float(1..10), _Float(finite?: true)
	refute_subtype _Float(1..), _Float(finite?: true)
	refute_subtype _Float(..10), _Float(finite?: true)
	refute_subtype _Interface(:a), _Constraint(_Interface(:a), _Interface(:b))
	refute_subtype _Interface(:a, :c), _Constraint(_Interface(:a, :b), _Interface(:c))

	assert_subtype _Constraint(Integer, 1..), Integer
	refute_subtype _Constraint(Integer, 1..), Float

	# Some property constraints prove class membership, but only on receivers
	# bounded by the fact’s receiver: an arbitrary object could patch
	# integer? or nil? to return anything.
	assert_subtype _Constraint(Numeric, integer?: true), Integer
	assert_subtype _Constraint(Numeric, integer?: true), Numeric
	assert_subtype _Constraint(Numeric, integer?: _Truthy), Integer
	assert_subtype _Constraint(10, integer?: true), Integer
	refute_subtype _Constraint(Comparable, integer?: true), Integer
	refute_subtype _Constraint(nil?: true), NilClass
	refute_subtype _Constraint(nil?: _Truthy), NilClass
	refute_subtype _Constraint(Numeric, integer?: true), Float
	refute_subtype _Constraint(Numeric, odd?: true), Integer

	# A constraint admitting falsy results proves nothing.
	refute_subtype _Constraint(Numeric, integer?: _Boolean), Integer
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
