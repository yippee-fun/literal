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
