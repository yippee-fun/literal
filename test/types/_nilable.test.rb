# frozen_string_literal: true

include Literal::Types

test "===" do
	type = _Nilable(String)

	assert type === "string"
	assert type === nil

	refute type === 42
	refute type === :symbol
	refute type === []
end

test "hierarchy" do
	assert_subtype String, _Nilable(String)
	assert_subtype _Nilable(String), _Nilable(String)
	assert_subtype nil, _Nilable(String)
	assert_subtype _Nilable(Array), _Nilable(Enumerable)
	assert_subtype Array, _Nilable(Enumerable)

	refute_subtype String, _Nilable(Enumerable)
end

test "a union of the same members is a subtype in both directions" do
	assert_subtype _Union(String, nil), _Nilable(String)
	assert_subtype _Nilable(String), _Union(String, nil)

	assert_subtype _Union(String, Symbol, nil), _Nilable(_Union(String, Symbol))
	assert_subtype _Union(String), _Nilable(String)
	assert_subtype _Union(Array, nil), _Nilable(Enumerable)

	refute_subtype _Union(String, Integer, nil), _Nilable(String)
	refute_subtype _Union(String, Integer), _Nilable(String)
end

test "nilable is idempotent" do
	type = _Nilable(String)

	assert_equal _Nilable(type), type
	assert_equal _Nilable(_Nilable(type)), type
end

test "nilable folds nil into a union rather than wrapping it" do
	# Wrapping would hide the members from anything inspecting the union, so
	# nesting `_Nilable` and `_Union` in either order gives the same type.
	folded = _Nilable(_Union(String, Symbol))

	assert Literal::Types::UnionType === folded
	assert_equal folded, _Union(String, Symbol, nil)
	assert_equal folded, _Union(_Nilable(String), Symbol)

	assert folded === nil
	assert folded === "string"
	assert folded === :symbol
	refute folded === 42
end

test "a single non-union type stays a nilable" do
	# NilableType has a much faster `===` than a union, so the common case must
	# not be canonicalised into one.
	assert Literal::Types::NilableType === _Nilable(String)
	assert Literal::Types::NilableType === _Nilable(_Array(String))
	assert Literal::Types::NilableType === _Any?
end

test "error message" do
	error = assert_raises Literal::TypeError do
		Literal.check({ 1 => 2, :a => :b, :d => 2 }, _Nilable(_Hash(Symbol, Integer)))
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    []
		      Expected: Symbol
		      Actual (Integer): 1
		    [:a]
		      Expected: Integer
		      Actual (Symbol): :b
	MSG
end
