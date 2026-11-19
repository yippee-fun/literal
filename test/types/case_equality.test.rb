# frozen_string_literal: true

include Literal::Types

test "=== returns true or false when a member returns something else" do
	truthy = -> (value) { value && :yes }
	falsy = -> (_value) { nil }

	assert_same true, _Deferred { truthy } === 1
	assert_same false, _Deferred { falsy } === 1

	assert_same true, _Nilable(truthy) === 1
	assert_same false, _Nilable(falsy) === 1

	assert_same true, _Frozen(truthy) === 1
	assert_same false, _Frozen(falsy) === 1

	assert_same true, _Range(truthy) === (1..2)
	assert_same false, _Range(falsy) === (1..2)

	assert_same true, _DraftState(truthy) === 1
	assert_same false, _DraftState(falsy) === 1

	assert_same true, Literal::Result(truthy, truthy) === Literal::Result(truthy, truthy).success(1)
	assert_same false, Literal::Result(falsy, truthy) === Literal::Result(truthy, truthy).success(1)
	assert_same true, Literal::Success(truthy) === Literal::Result(truthy, truthy).success(1)
	assert_same true, Literal::Failure(truthy) === Literal::Result(truthy, truthy).failure(1)
end

test "subtype? returns true or false" do
	assert_same false, Literal.subtype?(String, Integer)
	assert_same false, _Kind(Integer) === String
end
