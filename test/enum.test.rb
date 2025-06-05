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
		Color::SPRING_GREEN,
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

test "#find_by" do
	assert_equal Color::Red, Color.find_by(hex: "#FF0000")
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
