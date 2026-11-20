# frozen_string_literal: true

class MapTypeTest < Quickdraw::Test
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

		# A key the subtype doesn't constrain can hold anything.
		refute_subtype _Map(a: String), _Map(a: String, b: _Nilable(Integer))
		assert_subtype _Map(a: String), _Map(a: String, b: _Void)
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

	test "=== returns a boolean" do
		assert_equal true, _Map(a: String) === { a: "x" }
		assert_equal false, _Map(a: String) === { a: 1 }
	end

	test "inspect" do
		assert_equal "_Map(a: String, b: _Nilable(Integer))", _Map(a: String, b: _Nilable(Integer)).inspect
		assert_equal "_Map(\"a\" => String, 1 => Integer)", _Map("a" => String, 1 => Integer).inspect
		assert_equal "_Map(\"a b\": String, \"+\": String, \"c=\": String, d?: String)", _Map("a b": String, "+": String, "c=": String, d?: String).inspect
		assert_equal "_Map(\"ab\": String)", _Map("ab".encode(Encoding::UTF_16LE).to_sym => String).inspect
	end
end
