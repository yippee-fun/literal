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

test "values holding a BasicObject compare and hash by identity" do
	object = BasicObject.new
	value_class = Literal::Value(BasicObject)

	assert value_class.new(object).eql?(value_class.new(object))
	refute value_class.new(object).eql?(value_class.new(BasicObject.new))
	refute value_class.new(object).eql?(object)
	assert_equal value_class.new(object).hash, value_class.new(object).hash
	assert_equal({ value_class.new(object) => true }[value_class.new(object)], true)
end

test "values compare and hash a payload with a __send__ property" do
	payload = Class.new(Literal::Data) { prop :__send__, String }
	value_class = Literal::Value(payload)

	assert value_class.new(payload.new(__send__: "x")).eql?(value_class.new(payload.new(__send__: "x")))
	refute value_class.new(payload.new(__send__: "x")).eql?(value_class.new(payload.new(__send__: "y")))
	assert_equal value_class.new(payload.new(__send__: "x")).hash, value_class.new(payload.new(__send__: "x")).hash
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

test "from_pack restores nested values the type requires to be frozen" do
	names = Literal::Value(Literal::Types._Array(Literal::Types._Frozen(String)))
	frozen_names = Literal::Value(Literal::Types._Frozen(Literal::Types._Array(Literal::Types._Frozen(String))))

	loaded = names.from_pack(Marshal.load(Marshal.dump(names.new(["a"]).as_pack)))
	assert_equal loaded, names.new(["a"])
	assert loaded.value.first.frozen?
	refute loaded.value.frozen?

	loaded = frozen_names.from_pack(Marshal.load(Marshal.dump(frozen_names.new(["a"].freeze).as_pack)))
	assert_equal loaded, frozen_names.new(["a"].freeze)
	assert loaded.value.frozen?

	assert_equal names.from_pack([1, [+"a"], true]), names.new(["a"])
	assert_equal frozen_names.from_pack([1, [+"a"], true]), frozen_names.new(["a"].freeze)
end

test "from_pack restores frozen values through maps, tuples, sets, hashes, unions and constraints" do
	type = Literal::Types._Map(
		a: Literal::Types._Union(Literal::Types._Frozen(String), Integer),
		b: Literal::Types._Tuple(Literal::Types._Frozen(Literal::Types._Array(String)), Literal::Types._Set(Literal::Types._Frozen(String))),
		c: Literal::Types._Hash(String, Literal::Types._Constraint(String, frozen?: true)),
	)
	value_class = Literal::Value(type)
	value = value_class.new({ a: "x", b: [["y"].freeze, Set["z"]], c: { "k" => "v" } })
	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value.as_pack))).value

	assert loaded[:a].frozen?
	assert loaded[:b][0].frozen?
	assert loaded[:b][0][0].frozen?
	assert loaded[:b][1].first.frozen?
	assert loaded[:c]["k"].frozen?
	refute loaded[:b][1].frozen?
	refute loaded.frozen?
end

test "from_pack restores values that contain themselves" do
	type = Literal::Types._Deferred { Literal::Types._Union(Literal::Types._Array(type), Array) }
	value_class = Literal::Value(type)
	looped = []
	looped << looped

	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new(looped).as_pack))).value

	assert loaded.equal?(loaded.first)
end

test "from_pack restores frozen values through tagged unions and ranges" do
	tagged = Literal::Value(Literal::Types._TaggedUnion(names: Literal::Types._Array(Literal::Types._Frozen(String)), count: Integer))
	range = Literal::Value(Literal::Types._Range(Literal::Types._Frozen(String)))

	assert tagged.from_pack(Marshal.load(Marshal.dump(tagged.new(["a"]).as_pack))).value.first.frozen?
	assert range.from_pack(Marshal.load(Marshal.dump(range.new("a".."b").as_pack))).value.begin.frozen?
end

test "from_pack keeps a union member's values as they are when the value already matches it" do
	type = Literal::Types._Union(
		Literal::Types._Tuple(Literal::Types._Frozen(String), Integer),
		Literal::Types._Tuple(Literal::Types._String(frozen?: false), String),
	)
	value_class = Literal::Value(type)

	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new([+"x", +"y"]).as_pack))).value

	refute loaded.first.frozen?
end

test "from_pack loads values without a frozen? method" do
	value_class = Literal::Value(BasicObject)

	assert value_class.from_pack(value_class.new(BasicObject.new).as_pack)
end

test "from_pack refreezes a value whose own freeze is private or overridden" do
	private_freeze = Class.new { private def freeze = raise("private freeze called") }
	overridden_freeze = Class.new(private_freeze) { public def freeze = raise("overridden freeze called") }

	[private_freeze, overridden_freeze].each do |payload_class|
		value_class = Literal::Value(payload_class)
		loaded = value_class.from_pack(value_class.new(Literal::FREEZE.bind_call(payload_class.new)).as_pack)

		assert Literal::FROZEN.bind_call(loaded.value)
	end
end

test "from_pack keeps a value shared where the type requires it frozen" do
	shared = "x"
	value_class = Literal::Value(Literal::Types._Array(Literal::Types._Frozen(String)))
	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new([shared, shared]).as_pack)))

	assert loaded.value.all?(&:frozen?)
	assert loaded.value[0].equal?(loaded.value[1])

	shared = ["x"].freeze
	value_class = Literal::Value(Literal::Types._Hash(Symbol, Literal::Types._Frozen(Literal::Types._Array(String))))
	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new({ a: shared, b: shared }).as_pack)))

	assert loaded.value[:a].frozen?
	assert loaded.value[:a].equal?(loaded.value[:b])
end

test "from_pack restores a value shared between types that freeze it differently" do
	ranges = [("a".."b")].freeze
	value_class = Literal::Value(
		Literal::Types._Tuple(
			Literal::Types._Frozen(Array),
			Literal::Types._Frozen(Literal::Types._Array(Literal::Types._Range(Literal::Types._Frozen(String)))),
		),
	)
	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new([ranges, ranges]).as_pack)))

	assert_equal loaded.value, [ranges, ranges]
	assert loaded.value[1].first.begin.frozen?
end

test "from_pack restores through matchers that only implement ===" do
	matcher = BasicObject.new
	def matcher.===(value) = ::String === value

	value_class = Literal::Value(Literal::Types._Array(matcher))
	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new(["a", "a"]).as_pack)))

	assert_equal loaded.value, ["a", "a"]
end

test "from_pack restores frozen values that contain themselves" do
	value_class = Literal::Value(Literal::Types._Frozen(Array))
	looped = []
	looped << looped
	looped.freeze

	loaded = value_class.from_pack(Marshal.load(Marshal.dump(value_class.new(looped).as_pack))).value

	assert loaded.frozen?
	assert loaded.equal?(loaded.first)
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
