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
