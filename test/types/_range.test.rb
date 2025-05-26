# frozen_string_literal: true

include Literal::Types

test "_Range" do
	assert _Range(Integer) === (1..10)
	assert _Range(Float) === (1.0..10.0)
	assert _Range(String) === ("a".."z")

	refute _Range(Integer) === (1.0..10.0)
end

test "hierarchy" do
	assert_subtype _Range(Integer), _Range(Numeric)
	assert_subtype _Range(Integer), _Range(Integer)
	assert_subtype _Range(String), _Range(String)

	refute_subtype _Range(Float), _Range(Integer)
	refute_subtype nil, _Range(String)
end

test "type error" do
	message = assert_raises(Literal::TypeError) do
		Literal.check((1.0..10.0), _Range(Integer))
	end

	assert_equal message.message, <<~MSG
		Type mismatch

		  Expected: _Range(Integer)
		  Actual (Range): 1.0..10.0
	MSG
end
