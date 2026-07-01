# frozen_string_literal: true

include Literal::Types

test "===" do
	type = _Intersection(
		_Interface(:size),
		_Interface(:each),
	)

	assert type === []
	assert type === Set.new

	refute type === "string"
end

test "hierarchy" do
	assert_subtype _Intersection(String), _Intersection(String)
	assert_subtype _Constraint(String, size: 1..5), _Intersection(String)
	assert_subtype _Interface(:a, :b), _Intersection(_Interface(:a), _Interface(:b))
	assert_subtype _Interface(:a, :b, :c), _Intersection(_Interface(:a, :b), _Interface(:c))

	refute_subtype _Constraint(Integer, size: 1..2), _Intersection(String)
	refute_subtype _Interface(:a), _Intersection(_Interface(:a), _Interface(:b))
	refute_subtype _Interface(:a, :c), _Intersection(_Interface(:a, :b), _Interface(:c))
end

test "error message" do
	error = assert_raises(Literal::TypeError) do
		Literal.check(
			"string",
			_Intersection(
				_Interface(:size),
				_Interface(:each),
			)
		)
	end

	assert_equal error.message, <<~MSG
		Type mismatch

		    _Constraint(_Interface(:size), _Interface(:each))
		      Expected: _Interface(:each)
		      Actual (String): "string"
	MSG
end
