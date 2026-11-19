# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Boolean === true
	assert _Boolean === false

	refute _Boolean === nil
end

test "hierarchy" do
	assert_subtype true, _Boolean
	assert_subtype false, _Boolean
	assert_subtype TrueClass, _Boolean
	assert_subtype FalseClass, _Boolean
	assert_subtype _Boolean, _Boolean

	refute_subtype nil, _Boolean
end
