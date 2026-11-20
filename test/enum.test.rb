# frozen_string_literal: true

extend Literal::Types

class Color < Literal::Enum(Integer)
	prop :hex, String

	index :hex, String

	index :lower_hex, String, unique: false do |color|
		color.hex.downcase
	end

	Red = new(1, hex: "#FF0000")
	Green = new(2, hex: "#00FF00")
	Blue = new(3, hex: "#0000FF")
	SPRING_GREEN = new(4, hex: "#00FF7F")

	SPRING_GREEN_HEX = "#00FF7F"

	Scarlet = Red

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class Switch < Literal::Enum(_Boolean)
	On = new(true) do
		def toggle = Off
	end

	Off = new(false) do
		def toggle = On
	end

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SymbolTypedEnum < Literal::Enum(Symbol)
	A = new(:B)
	B = new(:A)
end

test ".coerce from value" do
	assert_equal Color.coerce(1), Color::Red
end

test ".coerce from enum" do
	assert_equal Color.coerce(Color::Red), Color::Red
end

test ".coerce from symbol" do
	assert_equal Color.coerce(:Red), Color::Red
end

test ".coerce with invalid symbol raises an ArgumentError" do
	assert_raises ArgumentError do
		Color.coerce(:Invalid)
	end
end

test ".coerce with the name of a constant that isn't a member raises an ArgumentError" do
	assert_raises ArgumentError do
		Color.coerce(:String)
	end

	assert_raises ArgumentError do
		Color.coerce(:SPRING_GREEN_HEX)
	end

	parent = Class.new(Literal::Enum(Integer)) { const_set(:One, new(1)) }
	child = Class.new(parent) { const_set(:Two, new(2)) }
	parent.const_set(:Foreign, child::Two)

	assert_raises ArgumentError do
		parent.coerce(:Foreign)
	end
end

test ".coerce with invalid value raises an ArgumenError" do
	assert_raises ArgumentError do
		Color.coerce("invalid value")
	end
end

test ".[] looks up the key by value" do
	assert_equal Color[1], Color::Red
end

test ".[] returns nil if the member can't be found" do
	assert_equal Color[10], nil
end

test ".cast looks up the key by value" do
	assert_equal Color.cast(1), Color::Red
end

test ".cast returns nil if the member can't be found" do
	assert_equal Color.cast(10), nil
end

test ".cast goes with the value when there are conflicts with the keys" do
	assert_equal SymbolTypedEnum.coerce(:A), SymbolTypedEnum::B
end

test ".position_of with member" do
	assert_equal Color.position_of(Color::Red), 0
	assert_equal Color.position_of(Color::Green), 1
	assert_equal Color.position_of(Color::Blue), 2
end

test ".position_of with name" do
	assert_equal Color.position_of(:Red), 0
	assert_equal Color.position_of(:Green), 1
	assert_equal Color.position_of(:Blue), 2
end

test ".position_of with value" do
	assert_equal Color.position_of(1), 0
	assert_equal Color.position_of(2), 1
	assert_equal Color.position_of(3), 2
end

test ".at_position" do
	assert_equal Color.at_position(0), Color::Red
	assert_equal Color.at_position(1), Color::Green
	assert_equal Color.at_position(2), Color::Blue
end

test ".to_set" do
	assert_equal Color.to_set, Set[
		Color::Red,
		Color::Green,
		Color::Blue,
		Color::SPRING_GREEN
	]
end

test ".to_h without block" do
	assert_equal Color.to_h, {
		Color::Red => 1,
		Color::Green => 2,
		Color::Blue => 3,
		Color::SPRING_GREEN => 4,
	}
end

test ".to_proc coerces" do
	assert_equal [1, :Green, Color::Blue].map(&Color), [
		Color::Red,
		Color::Green,
		Color::Blue,
	]
end

test ".to_s" do
	assert_equal Color::Red.to_s, "Red"
	assert_equal Color::SPRING_GREEN.to_s, "SPRING_GREEN"
	assert_equal Switch::On.to_s, "On"
	assert_equal SymbolTypedEnum::A.to_s, "A"
end

test ".to_sym" do
	assert_equal Color::Red.to_sym, :Red
	assert_equal Color::SPRING_GREEN.to_sym, :SPRING_GREEN
	assert_equal Switch::On.to_sym, :On
	assert_equal SymbolTypedEnum::A.to_sym, :A
end

test "#succ" do
	assert_equal Color::Red.succ, Color::Green
	assert_equal Color::Green.succ, Color::Blue
	assert_equal Color::Blue.succ, Color::SPRING_GREEN
	assert_equal Color::SPRING_GREEN.succ, nil
end

test "#pred" do
	assert_equal Color::Red.pred, nil
	assert_equal Color::Green.pred, Color::Red
	assert_equal Color::Blue.pred, Color::Green
end

test "#<=>" do
	assert_equal Color::Red <=> Color::Green, -1
	assert_equal Color::Red <=> Color::Red, 0
	assert_equal Color::Green <=> Color::Red, 1
	assert_equal Color::Red <=> Switch::On, nil
	assert_equal Color::Red <=> 1, nil
end

test "members are Comparable" do
	assert Color::Red < Color::Green
	assert Color::Blue > Color::Green
	assert Color::Green.between?(Color::Red, Color::Blue)
	assert_equal Color::SPRING_GREEN.clamp(Color::Red, Color::Blue), Color::Blue
	assert_equal [Color::Blue, Color::Red].max, Color::Blue

	assert_raises(ArgumentError) { Color::Red < Switch::On }
	refute Color::Red == Switch::On
	refute Color::Red == 1
	assert Color::Red == Color::Scarlet
end

test "members of a subclassed enum don't compare with the parent's" do
	parent = Class.new(Literal::Enum(Integer)) { const_set(:One, new(1)) }
	child = Class.new(parent) { const_set(:Two, new(2)) }

	assert_equal parent::One <=> child::Two, nil
	refute parent::One == child::Two
	refute child::Two == parent::One
	refute parent::One === child::Two
end

test "#name" do
	assert Color::Red.name.end_with?("Color::Red")
end

test "enums are rangeable" do
	range = (Color::Red..Color::Green)

	assert Range === range
	assert_equal Color::Red, range.begin
	assert_equal Color::Green, range.end
end

test "#where" do
	assert_equal [Color::Red], Color.where(hex: "#FF0000")
end

test "#where raises Literal::TypeError when index value has the wrong type" do
	assert_raises(Literal::TypeError) do
		Color.where(hex: 123)
	end
end

test "#find_by" do
	assert_equal Color::Red, Color.find_by(hex: "#FF0000")
end

test "index definitions raise Literal::TypeError when index key type is wrong" do
	klass = Class.new(Literal::Enum(Integer)) do
		index :bad, String, &:value

		A = new(1)
	end

	assert_raises(Literal::TypeError) do
		klass.__after_defined__
	end
end

test "#find_by raises when used with a non-unique index" do
	error = assert_raises(ArgumentError) { Color.find_by(lower_hex: "#ff0000") }
	assert_equal error.message, "You can only use `find_by` on unique indexes."
end

test "#value returns the value" do
	assert_equal Color::Red.value, 1
end

test "reading property readers" do
	assert_equal Color::Red.hex, "#FF0000"
end

test "generated predicates" do
	assert_equal Color::Red.red?, true
	assert_equal Color::Red.green?, false
	assert_equal Color::Red.blue?, false
	assert_equal Color::Red.spring_green?, false
	assert_equal Color::SPRING_GREEN.spring_green?, true
end

test "members are frozen" do
	assert Color::Red.frozen?
end

test "classes are frozen" do
	assert Color.frozen?
end

test "singleton methods" do
	assert_equal Switch::Off.toggle, Switch::On
	assert_equal Switch::On.toggle, Switch::Off
end

test do
	assert_equal([Color::Blue, Color::Green, Color::Red], [3, 2, 1].map(&Color))
	assert_equal([Color::Red, Color::Green], [Color::Red, 2].map(&Color))
end

test "pattern matching" do
	match { Color::Red => Color }
	match { Color::Red => Color[1] }
	match { Color::Red => Color[hex: "#FF0000"] }
end

test "members are tracked by their constant names" do
	assert_equal Literal.const_name(Color::Red), Color::Red.name
end

test "an alias keeps the member's name and gets a predicate of its own" do
	assert Color::Scarlet.equal?(Color::Red)
	assert Color::Red.name.end_with?("Color::Red")
	assert_equal Color::Red.to_sym, :Red
	assert Color::Red.scarlet?
	refute Color::Green.scarlet?
	assert_equal Color.coerce(:Scarlet), Color::Red
end

test "prop? defines an optional property with a public reader" do
	enum = Class.new(Literal::Enum(Integer)) do
		prop? :label, String

		const_set(:Labelled, new(1, label: "One"))
		const_set(:Plain, new(2))
	end

	assert_equal enum::Labelled.label, "One"
	assert_equal enum::Plain.label, Literal::Undefined
end

test ".each without a block returns an enumerator" do
	enumerator = Color.each

	assert Enumerator === enumerator
	assert_equal enumerator.size, 4
	assert_equal enumerator.with_index.to_a.first, [Color::Red, 0]
end

test "members are singletons, so dup and clone return the member" do
	assert Color::Red.dup.equal?(Color::Red)
	assert Color::Red.clone.equal?(Color::Red)
	assert Color::Red.clone(freeze: true).equal?(Color::Red)
	assert_raises(ArgumentError) { Color::Red.clone(freeze: false) }
	assert_raises(ArgumentError) { Color::Red.clone(freeze: :junk) }
end

test "members load from their dump" do
	assert Color._load(Color::Blue._dump(-1)).equal?(Color::Blue)
end

test "loading a value that isn't a member raises" do
	assert_raises(KeyError) { Color._load(Marshal.dump(99)) }
end

test "#find_by with more than one index names find_by" do
	error = assert_raises(ArgumentError) { Color.find_by(hex: "#FF0000", lower_hex: "#ff0000") }
	assert_equal error.message, "You can only specify one index when using `find_by`."
end

test "a member of an anonymous enum is named after the enum's inspect" do
	enum = Class.new(Literal::Enum(Integer)) do
		const_set(:A, new(1))
	end

	assert_equal enum::A.name, "#{enum.inspect}::A"

	error = assert_raises(ArgumentError) { enum.new(1) }
	assert_equal error.message, "The value 1 is already used by #{enum.inspect}::A."
end

test "a member whose predicate would override an existing method is refused" do
	[[:Nil, :nil?], [:Frozen, :frozen?], [:Between, :between?]].each do |member, predicate|
		error = assert_raises(Literal::ArgumentError) do
			Class.new(Literal::Enum(Integer)) { const_set(member, new(1)) }
		end

		assert error.message.include?("The member #{member}")
		assert error.message.include?("##{predicate}")
	end

	assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Enum(Integer)) do
			prop :active, _Boolean, predicate: :public
			const_set(:Active, new(1, active: true))
		end
	end
end

test "refusing a member built before others keeps their positions" do
	enum = Class.new(Literal::Enum(Integer))
	first = enum.new(1)
	second = enum.new(2)
	assert_raises(Literal::ArgumentError) { enum.const_set(:Nil, first) }
	enum.const_set(:Second, second)

	assert_equal enum::Second.pred, first
	assert_equal enum.position_of(enum::Second), 1
end

test "a property named __position__ keeps its own slot" do
	enum = Class.new(Literal::Enum(Integer)) do
		prop :__position__, Integer, reader: false
		const_set(:A, new(1, __position__: 10))
		const_set(:B, new(2, __position__: 20))
	end

	assert_equal enum::A.succ, enum::B
	assert_equal enum::A.to_h[:__position__], 10
	assert enum::A < enum::B
end

test "a refused member leaves nothing behind" do
	enum = Class.new(Literal::Enum(Integer)) do
		const_set(:A, new(1))
	end

	assert_raises(Literal::ArgumentError) { enum.const_set(:Nil, enum.new(2)) }

	refute enum.const_defined?(:Nil, false)
	assert_equal enum[2], nil
	assert_equal enum.members, [enum::A]

	enum.const_set(:B, enum.new(2))
	assert_equal enum::B.__position__, 1
end
