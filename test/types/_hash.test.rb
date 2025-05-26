# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Hash(String, Integer) === { "a" => 1, "b" => 2 }
	assert _Hash(Symbol, String) === { foo: "bar", baz: "qux" }

	refute _Hash(String, Integer) === { "a" => "1", "b" => 2 }
	refute _Hash(String, Integer) === { 1 => 2, 3 => 4 }
	refute _Hash(Symbol, String) === { "foo" => "bar", :baz => "qux" }
end

test "hierarchy" do
	assert_subtype _Hash(String, Integer), _Hash(String, Numeric)
	assert_subtype _Hash(Integer, String), _Hash(Numeric, String)
	assert_subtype _Hash(Symbol, Integer), _Hash(Symbol, Integer)

	refute_subtype _Hash(Symbol, Numeric), _Hash(Symbol, Integer)
end

test "key error" do
	error = assert_raises Literal::TypeError do
		Literal.check({ 1 => 2, :a => :b, :d => 2 }, _Hash(Symbol, Integer))
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

test "top level error" do
	error = assert_raises Literal::TypeError do
		Literal.check(nil, _Hash(Symbol, Integer))
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		  Expected: _Hash(Symbol, Integer)
		  Actual (NilClass): nil
	MSG
end
