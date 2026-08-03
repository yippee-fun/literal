# frozen_string_literal: true

include Literal::Types

test "===" do
	object = -> { "hello" }

	assert _SameObject(object) === object
	refute _SameObject(object) === -> { "hello" }
end

test "hierarchy" do
	object = "a"

	assert_subtype _SameObject(object), _SameObject(object)
	refute_subtype _SameObject(object), _SameObject(+"a")

	# The only value is the object itself, so any type admitting it is a supertype.
	assert_subtype _SameObject(object), String
	assert_subtype _SameObject(10), Integer
	assert_subtype _SameObject(10), 5..15
	refute_subtype _SameObject(object), Symbol
end
