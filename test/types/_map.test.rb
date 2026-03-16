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

test "optional and never keys" do
	map = _Map(name: String, nickname: nil, password: _Never)

	assert map === { name: "Alice" }
	assert map === { name: "Alice", nickname: nil }

	refute map === { name: "Alice", nickname: "Al" }
	refute map === { name: "Alice", password: "secret" }
end

test "nilable optional keys" do
	map = _Map(name: String, nickname: _Nilable(String))

	assert map === { name: "Alice" }
	assert map === { name: "Alice", nickname: nil }
	assert map === { name: "Alice", nickname: "Al" }

	refute map === { name: "Alice", nickname: 123 }
end

test "extra keys are ignored" do
	map = _Map(name: String)

	assert map === { name: "Alice", age: 42 }
end

test "missing nilable key matches in small-hash branch" do
	map = _Map(
		name: String,
		nickname: _Nilable(String),
		bio: _Nilable(String),
		location: _Nilable(String),
	)

	assert map === { name: "Alice" }
end

test "forbidden key rejects nil too" do
	map = _Map(name: String, password: _Never)

	refute map === { name: "Alice", password: nil }
end

test "missing required nilable value key still matches" do
	map = _Map(name: _Nilable(String))

	assert map === {}
	assert map === { name: nil }
	assert map === { name: "Alice" }

	refute map === { name: 123 }
end

test "hierarchy" do
	assert_subtype _Map(a: Array, b: Integer, foo: String), _Map(a: Enumerable, b: Numeric)
	refute_subtype _Map(a: Array), _Map(a: Enumerable, b: Numeric)
	refute_subtype _Map(a: String, b: Integer), _Map(a: Enumerable, b: Numeric)
	refute_subtype nil, _Map(a: String)
end

test "hierarchy with optional and never keys" do
	assert_subtype _Map(name: String, nickname: nil, password: _Never), _Map(name: String, nickname: nil)
	assert_subtype _Map(name: String, password: _Never), _Map(name: String, password: _Never)
	assert_subtype _Map(name: String), _Map(name: String, nickname: nil)
	assert_subtype _Map(name: String), _Map(name: String, nickname: _Nilable(String))

	refute_subtype _Map(name: String), _Map(name: String, password: _Never)
	refute_subtype _Map(name: String, password: nil), _Map(name: String, password: _Never)
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
