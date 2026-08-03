# frozen_string_literal: true

test "literal values are subtypes of their module supertypes" do
	assert_subtype "Hello", String
	assert_subtype "Hello", Object
	assert_subtype "Hello", Comparable

	assert_subtype :hello, Symbol
	assert_subtype :hello, Object

	assert_subtype [], Array
	assert_subtype [], Enumerable
	assert_subtype [], Object

	assert_subtype({}, Hash)
	assert_subtype({}, Enumerable)
	assert_subtype({}, Object)

	date = Date.new(2025, 1, 13)

	assert_subtype date, Date
	assert_subtype date, Object
end

include Literal::Types

test "recursive types can be compared" do
	json_data = nil
	json_data = _Union(
		String, Integer, Float, true, false, nil,
		_Deferred { _Array(json_data) },
		_Deferred { _Hash(String, json_data) },
	)

	strict_json_data = nil
	strict_json_data = _Union(
		String, Integer,
		_Deferred { _Array(strict_json_data) },
	)

	assert_subtype json_data, json_data
	assert_subtype strict_json_data, json_data
	assert_subtype _Array(strict_json_data), _Array(json_data)

	refute_subtype json_data, strict_json_data
	refute_subtype _Array(json_data), _Array(strict_json_data)
end
