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

test "==, eql? and hash agree" do
	other_id = Literal::Delegator(String)

	assert_equal UserID.new("a"), UserID.new("a")
	assert UserID.new("a").eql?(UserID.new("a"))
	assert_equal UserID.new("a").hash, UserID.new("a").hash

	refute_equal UserID.new("a"), other_id.new("a")
	refute UserID.new("a").eql?(other_id.new("a"))
	refute UserID.new("a").eql?("a")
	assert_equal({ UserID.new("a") => 1, other_id.new("a") => 2 }.size, 2)
end
