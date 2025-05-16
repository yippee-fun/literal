# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _JSONData === "string"
	assert _JSONData === 42
	assert _JSONData === 3.14
	assert _JSONData === true
	assert _JSONData === false
	assert _JSONData === nil
	assert _JSONData === { "key" => "value", "number" => 42 }
	assert _JSONData === [1, "two", 3.0, true, false, nil]

	assert _JSONData === { "nested_array" => [1, "two", { "key" => "value" }] }
	assert _JSONData === { "nested_hash" => { "key1" => "value1", "key2" => [1, 2, 3] } }
	assert _JSONData === [{ "key" => "value" }, [1, 2, 3], "string"]

	refute _JSONData === Object.new
	refute _JSONData === Set.new
	refute _JSONData === { key: "value" }
	refute _JSONData === [1, :symbol, "three"]
	refute _JSONData === { "nested_array" => [1, :symbol, { "key" => "value" }] }
	refute _JSONData === { "nested_hash" => { "key1" => "value1", "key2" => [1, :symbol, 3] } }
	refute _JSONData === [{ "key" => :value }, [1, 2, 3], "string"]
end

test "with params" do
	assert _JSONData(Array) === [1, 2, 3]
	refute _JSONData(Array) === ["a", 1, 2, Object.new]
end

test "hierarchy" do
	assert_subtype _JSONData, _JSONData

	assert_subtype nil, _JSONData
	assert_subtype false, _JSONData
	assert_subtype true, _JSONData
	assert_subtype Float, _JSONData
	assert_subtype String, _JSONData
	assert_subtype Integer, _JSONData

	assert_subtype _Array(_JSONData), _JSONData
	assert_subtype _Array(nil), _JSONData
	assert_subtype _Array(false), _JSONData
	assert_subtype _Array(true), _JSONData
	assert_subtype _Array(Float), _JSONData
	assert_subtype _Array(String), _JSONData
	assert_subtype _Array(Integer), _JSONData

	assert_subtype _Hash(_JSONData, _JSONData), _JSONData
	assert_subtype _Hash(nil, _JSONData), _JSONData
	assert_subtype _Hash(false, _JSONData), _JSONData
	assert_subtype _Hash(true, _JSONData), _JSONData
	assert_subtype _Hash(Float, _JSONData), _JSONData
	assert_subtype _Hash(String, _JSONData), _JSONData
	assert_subtype _Hash(Integer, _JSONData), _JSONData

	assert_subtype _Hash(_JSONData, nil), _JSONData
	assert_subtype _Hash(_JSONData, false), _JSONData
	assert_subtype _Hash(_JSONData, true), _JSONData
	assert_subtype _Hash(_JSONData, Float), _JSONData
	assert_subtype _Hash(_JSONData, String), _JSONData
	assert_subtype _Hash(_JSONData, Integer), _JSONData

	assert_subtype _Float(5..10), _JSONData
	assert_subtype _String(length: 10), _JSONData
	assert_subtype _Integer(5..10), _JSONData

	# not compatible since we don’t know what’s inside the array
	refute_subtype Array, _JSONData

	# not compatible since we don’t know what’s inside the hash
	refute_subtype Hash, _JSONData

	# not compatible since we know the array contains symbols
	refute_subtype _Array(Symbol), _JSONData
end

test "error message" do
	error = assert_raises(Literal::TypeError) do
		Literal.check(
			{ :key => "value", "string" => "string", "symbol" => :symbol, "array" => [1, 2, 3, :symbol], "hash" => { "key" => "value", "symbol" => :symbol } },
			_JSONData
		)
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    []
		      Expected: String
		      Actual (Symbol): :key
		    ["symbol"]
		      Expected: _JSONData
		      Actual (Symbol): :symbol
		    ["array"]
		      [3]
		        Expected: _JSONData
		        Actual (Symbol): :symbol
		    ["hash"]
		      ["symbol"]
		        Expected: _JSONData
		        Actual (Symbol): :symbol
	MSG
end
