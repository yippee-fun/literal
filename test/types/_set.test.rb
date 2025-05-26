# frozen_string_literal: true

include Literal::Types

test "_Set" do
	assert _Set(String) === Set["a", "b", "c"]
	assert _Set(Integer) === Set[1, 2, 3]

	refute _Set(String) === Set[1, "a", :symbol]
	refute _Set(Integer) === Set["a", "b", "c"]
	refute _Set(String) === ["a", "b", "c"]
end

test "hierarchy" do
	assert_subtype _Set(String), _Set(String)
	assert_subtype _Set(Integer), _Set(Numeric)

	refute_subtype _Set(Integer), _Set(String)
	refute_subtype Numeric, _Set(Numeric)
end

test "error message" do
	error = assert_raises(Literal::TypeError) do
		Literal.check(Set["1", 2, "3", nil], _Set(String))
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    []
		      Expected: String
		      Actual (Integer): 2
		    []
		      Expected: String
		      Actual (NilClass): nil
	MSG
end
