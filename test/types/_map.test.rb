# frozen_string_literal: true

include Literal::Types

test "===" do
	map = _Map(name: String, age: Integer)

	assert map === { name: "Alice", age: 42 }
	assert map === { name: "Bob", age: 18 }

	refute map === { name: "Alice", age: "42" }
	refute map === { name: "Bob", age: nil }
	refute map === { name: "Charlie" }
	refute map === { age: 30 }
end

test "hierarchy" do
	assert_subtype _Map(a: Array, b: Integer, foo: String), _Map(a: Enumerable, b: Numeric)
	refute_subtype _Map(a: Array), _Map(a: Enumerable, b: Numeric)
	refute_subtype _Map(a: String, b: Integer), _Map(a: Enumerable, b: Numeric)
	refute_subtype nil, _Map(a: String)
end

test "error message" do
	error = assert_raises Literal::TypeError do
		Literal.check(
			{ name: "Alice", age: "42" },
			_Map(name: String, age: Integer),
		)
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    [:age]
		      Expected: Integer
		      Actual (String): "42"
	MSG
end
