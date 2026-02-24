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
end
