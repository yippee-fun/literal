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

test "equal values are eql? and hash alike" do
	assert Age.new(20).eql?(Age.new(20))
	assert_equal Age.new(20).hash, Age.new(20).hash
	assert_equal({ Age.new(20) => true }[Age.new(20)], true)

	refute Age.new(20).eql?(UserID.new(20))

	number = Literal::Value(Numeric)

	assert_equal number.new(1), number.new(1.0)
	refute number.new(1).eql?(number.new(1.0))
end

test "eql? and hash agree when a subclass overrides the reader" do
	shouting = Class.new(Literal::Value(String)) do
		def value = super.upcase
	end

	assert shouting.new("a").eql?(shouting.new("a"))
	assert shouting.new("a").eql?(shouting.new("A"))
	assert_equal shouting.new("a").hash, shouting.new("A").hash
end

test "from_pack type checks the value" do
	assert_equal Age.from_pack(Age.new(20).as_pack), Age.new(20)

	assert_raises(Literal::TypeError) { Age.from_pack([1, "not an int", true]) }
	assert_raises(Literal::TypeError) { Age.from_pack([1, 17, true]) }
end

test "from_pack restores the value's frozen state before checking it" do
	frozen_name = Literal::Value(Literal::Types._Frozen(String))
	pack = Marshal.load(Marshal.dump(frozen_name.new("Joel").as_pack))

	assert_equal frozen_name.from_pack(pack), frozen_name.new("Joel")
	assert_equal Age.from_pack([1, 20, true]), Age.new(20)
end

test "from_pack loads version 1 payloads, which don't record the value's frozen state" do
	frozen_name = Literal::Value(Literal::Types._Frozen(String))
	name = Literal::Value(String)

	frozen_loaded = frozen_name.from_pack(Marshal.load(Marshal.dump([1, "Joel", true])))
	loaded = name.from_pack(Marshal.load(Marshal.dump([1, "Joel", true])))

	assert_equal frozen_loaded, frozen_name.new("Joel")
	assert frozen_loaded.value.frozen?
	refute loaded.value.frozen?
	assert_raises(Literal::TypeError) { frozen_name.from_pack([1, 1, true]) }

	mutable = []
	assert_raises(Literal::TypeError) { name.from_pack([1, mutable, true]) }
	refute mutable.frozen?

	checks = 0
	counted = Literal::Value(-> (_value) { checks += 1 })
	counted.from_pack([1, "a", true])
	assert_equal checks, 1
end
