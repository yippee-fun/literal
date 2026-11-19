# frozen_string_literal: true

class ::AttributeColor < Literal::Enum(Integer)
	Red = new(1)
	Green = new(2)
end

class ::AttributeColorModel
	include ActiveModel::Model
	include ActiveModel::Attributes
	extend Literal::Rails::EnumMacro

	attribute :color, :integer
	literal_enum :color, AttributeColor
end

test "casts through the declared attribute type" do
	model = AttributeColorModel.new

	model.color = "2"
	assert_equal AttributeColor::Green, model.color

	model.color = AttributeColor::Red
	assert_equal AttributeColor::Red, model.color

	model.color = :Green
	assert_equal AttributeColor::Green, model.color

	model.color = nil
	assert_equal nil, model.color

	model.color = ""
	assert_equal nil, model.color
end

test "delegates serializable? to the declared attribute type" do
	enum = Class.new(Literal::Enum(Integer)) do
		const_set(:Small, new(1))
		const_set(:Huge, new(2 ** 40))
	end

	type = Literal::Rails::EnumType.new(enum, ActiveModel::Type::Integer.new(limit: 4))

	assert type.serializable?(enum::Small)
	refute type.serializable?(enum::Huge)
end

test "serializes through the declared attribute type" do
	type = AttributeColorModel.type_for_attribute(:color)

	assert_equal 2, type.serialize(AttributeColor::Green)
	assert_equal 1, type.serialize("1")
	assert_equal nil, type.serialize(nil)
	assert_equal AttributeColor::Green, type.deserialize("2")
	assert_equal nil, type.deserialize(nil)
end

test "rejects values that aren't members" do
	model = AttributeColorModel.new

	model.color = 3
	assert_raises(ArgumentError) { model.color }
end

test "accepts a default" do
	model_class = Class.new do
		include ActiveModel::Attributes
		extend Literal::Rails::EnumMacro

		attribute :color, :integer
		literal_enum :color, AttributeColor, default: AttributeColor::Green
	end

	assert_equal AttributeColor::Green, model_class.new.color
end

test "redeclaring wraps the original type rather than the previous enum type" do
	model_class = Class.new(AttributeColorModel) do
		literal_enum :color, AttributeColor
	end

	type = model_class.type_for_attribute(:color)

	assert Literal::Rails::EnumType === type
	assert ActiveModel::Type::Integer === type.subtype
end

test "raises when the attribute has no declared type" do
	model_class = Class.new do
		include ActiveModel::Attributes
		extend Literal::Rails::EnumMacro

		literal_enum :color, AttributeColor
	end

	assert_raises(Literal::ArgumentError) { model_class.new }
end

class ::TypedStatus < Literal::Enum(Symbol)
	Active = new(:active)
	Archived = new(:archived)
end

class ::TypedLevel < Literal::Enum(Integer)
	None = new(0)
	Low = new(1)
	High = new(2)
end

class ::TypedBlankSymbol < Literal::Enum(Symbol)
	Empty = new(:"")
end

class ::TypedSwitch < Literal::Enum(Literal::Types._Boolean)
	On = new(true)
	Off = new(false)
end

class ::TypedCode < Literal::Enum(String)
	Empty = new("")
	Filled = new("x")
end

status = Literal::Rails::EnumType.new(TypedStatus)
level = Literal::Rails::EnumType.new(TypedLevel)
switch = Literal::Rails::EnumType.new(TypedSwitch)
code = Literal::Rails::EnumType.new(TypedCode)

test "members, backing values and member names cast" do
	assert_equal status.cast(TypedStatus::Active), TypedStatus::Active
	assert_equal status.cast(:active), TypedStatus::Active
	assert_equal level.cast(1), TypedLevel::Low
	assert_equal level.cast(:High), TypedLevel::High
end

test "a Symbol-backed enum reads back from a string column" do
	assert_equal status.deserialize("active"), TypedStatus::Active
	assert_equal status.cast("archived"), TypedStatus::Archived

	string_column = Literal::Rails::EnumType.new(TypedStatus, ActiveModel::Type::String.new)
	assert_equal string_column.deserialize("active"), TypedStatus::Active
	assert_equal string_column.serialize(TypedStatus::Active), "active"
end

test "a string casts to the member whose backing value reads the same" do
	assert_equal level.cast("1"), TypedLevel::Low
	assert_equal level.deserialize("2"), TypedLevel::High
	assert_equal switch.cast("true"), TypedSwitch::On
	assert_equal switch.cast("false"), TypedSwitch::Off
end

test "a string that only loosely reads as a backing value raises" do
	assert_raises(ArgumentError) { level.cast("garbage") }
	assert_raises(ArgumentError) { level.serialize("1oops") }
	assert_raises(ArgumentError) { switch.cast("garbage") }
end

test "blank input casts to nil" do
	assert_equal level.cast(""), nil
	assert_equal level.cast("  "), nil
	assert_equal level.cast(" ".encode(Encoding::UTF_16LE)), nil
	assert_equal status.deserialize(""), nil
	assert_equal level.cast(nil), nil
end

test "a blank string that is a backing value casts to its member" do
	assert_equal code.cast(""), TypedCode::Empty
	assert_equal Literal::Rails::EnumType.new(TypedBlankSymbol).deserialize(""), TypedBlankSymbol::Empty
end

test "input with no member raises" do
	assert_raises(ArgumentError) { level.cast("3") }
	assert_raises(ArgumentError) { status.deserialize("deleted") }
end

test "serializes to the backing value" do
	assert_equal status.serialize(TypedStatus::Active), :active
	assert_equal level.serialize("2"), 2
	assert_equal level.serialize(nil), nil
end

test "types are equal only with the same enum and subtype" do
	assert_equal level, Literal::Rails::EnumType.new(TypedLevel)
	assert level.eql?(Literal::Rails::EnumType.new(TypedLevel))
	assert_equal level.hash, Literal::Rails::EnumType.new(TypedLevel).hash

	refute_equal level, status
	refute level.eql?(status)
	refute_equal level.hash, status.hash

	integer_column = Literal::Rails::EnumType.new(TypedLevel, ActiveModel::Type::Integer.new)
	assert_equal integer_column, Literal::Rails::EnumType.new(TypedLevel, ActiveModel::Type::Integer.new)
	refute_equal level, integer_column
	refute level.eql?(integer_column)
	refute_equal level.hash, integer_column.hash
end
