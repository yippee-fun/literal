# frozen_string_literal: true

class DelegatorTest < Quickdraw::Test
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

	test "delegators compare and hash a payload without eql? or hash by identity" do
		bare = Class.new { undef_method :eql?, :hash }
		delegator = Literal::Delegator(bare)
		object = bare.new

		assert delegator.new(object) == delegator.new(object)
		assert delegator.new(object).eql?(delegator.new(object))
		refute delegator.new(object).eql?(delegator.new(bare.new))
		refute delegator.new(object).eql?(BasicObject.new)
		assert_equal delegator.new(object).hash, delegator.new(object).hash
		assert_equal({ delegator.new(object) => true }[delegator.new(object)], true)
	end

	test "delegators compare and hash a payload with a __send__ property" do
		payload = Class.new(Literal::Data) { prop :__send__, String }
		delegator = Literal::Delegator(payload)

		assert delegator.new(payload.new(__send__: "x")).eql?(delegator.new(payload.new(__send__: "x")))
		refute delegator.new(payload.new(__send__: "x")).eql?(delegator.new(payload.new(__send__: "y")))
		assert_equal delegator.new(payload.new(__send__: "x")).hash, delegator.new(payload.new(__send__: "x")).hash
	end
end
