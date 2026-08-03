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

test "numeric literals are bounded by Numeric, not their own class" do
	# 10 admits 10.0, 10r and BigDecimal("10") via ==, so Integer is not a
	# sound bound. Class-anchored spellings are.
	assert_subtype 10, Numeric
	assert_subtype 10, 5..15
	assert_subtype 1.5, Numeric

	refute_subtype 10, Integer
	refute_subtype 1.5, Float

	assert_subtype _Integer(10), Integer
	assert_subtype _SameObject(10), Integer
	assert_subtype _Constraint(10, integer?: true), Integer

	refute_subtype _Constraint(10, integer?: false), Integer
	refute_subtype _SameObject(10.0), Integer
end

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
