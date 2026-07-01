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
