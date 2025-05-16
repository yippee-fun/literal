# frozen_string_literal: true

include Literal::Types

test "===" do
	object = -> { "hello" }

	assert _Unit(object) === object
	refute _Unit(object) === -> { "hello" }
end

test "hierarchy" do
	object = "a"

	assert_subtype _Unit(object), _Unit(object)
	refute_subtype _Unit(object), _Unit(+"a")
end
