# frozen_string_literal: true

UserID = Literal::Delegator(String) do
	def double = length * 2
end

test ".===" do
	user_id = UserID.new("123")
	assert UserID === user_id
end

test ".[]" do
	user_id = UserID["123"]
	assert UserID === user_id
end

test "custom methods" do
	user_id = UserID.new("123")
	assert_equal user_id.double, 6
end

test "#===" do
	user_id = UserID.new("123")

	assert user_id === user_id
	refute user_id === "123"
end
