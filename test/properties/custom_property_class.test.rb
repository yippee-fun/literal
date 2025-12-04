# frozen_string_literal: true

class DescriptionProperty < Literal::Property
	def initialize(description: nil, **kwargs)
		super(**kwargs)

		@description = description
	end

	attr_reader :description
end

module DescriptionProperties
	def prop(name, type, kind = :keyword, description: nil, **, &coercion)
		super
	end

	def __literal_property_class__
		DescriptionProperty
	end
end

Example = Literal::Object

test "custom property class can accept additional keyword arguments" do
	example = Class.new(Example) do
		extend DescriptionProperties

		prop :name, String, description: "The person's name"
		prop :age, Integer, description: "The person's age"
	end

	name_prop = example.literal_properties[:name]
	age_prop = example.literal_properties[:age]

	assert_equal name_prop.description, "The person's name"
	assert_equal age_prop.description, "The person's age"
	assert_equal name_prop.class, DescriptionProperty
	assert_equal age_prop.class, DescriptionProperty
end

test "custom property class works with all property features" do
	example = Class.new(Example) do
		extend DescriptionProperties

		prop :name, String, description: "Name", reader: :public
		prop :age, Integer, description: "Age", default: 0, reader: :public
	end

	object = example.new(name: "John")
	assert_equal object.name, "John"
	assert_equal object.age, 0

	name_prop = example.literal_properties[:name]
	age_prop = example.literal_properties[:age]

	assert_equal name_prop.description, "Name"
	assert_equal age_prop.description, "Age"
end

test "custom property class with nil description" do
	example = Class.new(Example) do
		extend DescriptionProperties

		prop :name, String
	end

	name_prop = example.literal_properties[:name]
	assert_equal name_prop.description, nil
end

test "invalid keyword arguments on base Literal::Properties raise ArgumentError" do
	example = Class.new(Example)

	assert_raises(ArgumentError) do
		example.prop :name, String, description: "This should fail"
	end
end

test "invalid keyword arguments on base Literal::Properties raise ArgumentError for other unknown args" do
	example = Class.new(Example)

	assert_raises(ArgumentError) do
		example.prop :name, String, unknown_arg: "This should fail"
	end
end
