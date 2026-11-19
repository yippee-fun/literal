# frozen_string_literal: true

UserID = Literal::Value(Integer)
Age = Literal::Value(Integer, 18..)
Name = Literal::Value(String) do
	delegate :length
end

class Email < Literal::Value(String)
	delegate :length

	def domain
		value.split("@").last
	end
end

test do
	user_id = UserID.new(123)
	assert_equal(123, user_id.to_i)

	assert_raises Literal::TypeError do
		Age.new(17)
	end

	name = Name.new("Joel")
	assert_equal 4, name.length
end

test "class inheritance" do
	email = Email.new("joel@drapper.me")

	assert_equal email.domain, "drapper.me"
	assert_equal email.length, 15
	assert_equal email.to_s, "joel@drapper.me"
	assert_equal email.to_str, "joel@drapper.me"

	assert Email === email
	refute String === email
end

test "collection values convert to their core collection" do
	assert_equal [1], Literal::Value(Array).new([1]).to_a
	assert_equal [1], Literal::Value(Array).new([1]).to_ary
	assert_equal({ a: 1 }, Literal::Value(Hash).new({ a: 1 }).to_h)
	assert_equal Set[1], Literal::Value(Set).new(Set[1]).to_set
end
