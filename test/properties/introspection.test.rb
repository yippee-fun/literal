# frozen_string_literal: true

class BasicIntrospection
	extend Literal::Properties
	extend Literal::Properties::Introspection

	prop :id, Integer, :positional, description: "Unique identifier"
	prop :name, String, :positional
	prop :age, Integer, description: "Age in years"
	prop :email, _Nilable(String)
	prop :friends, _Array(String), :*
	prop :options, _Hash(Symbol, String), :**
	prop :block, _Nilable(Proc), :&
end

class WithOptionals
	extend Literal::Properties
	extend Literal::Properties::Introspection

	prop :required_pos, String, :positional
	prop :optional_pos, String, :positional, default: "default"
	prop :optional_name, _Nilable(String), :positional
	prop :required_kw, Integer
	prop :optional_kw, Integer, default: 42
	prop :tags, _Array(String), default: -> { [] }
	prop :created_at, _Nilable(Time)
end

class EmptyWithIntrospection
	extend Literal::Properties
	extend Literal::Properties::Introspection
end

test "positional_properties returns all positional properties" do
	props = BasicIntrospection.positional_properties
	assert_equal props.map(&:name), [:id, :name]
	assert props.all?(&:positional?)
end

test "positional_property_names returns all positional property names" do
	names = BasicIntrospection.positional_property_names
	assert_equal names, [:id, :name]
end

test "keyword_properties returns all keyword properties" do
	props = BasicIntrospection.keyword_properties
	assert_equal props.map(&:name), [:age, :email]
	assert props.all?(&:keyword?)
end

test "keyword_property_names returns all keyword property names" do
	names = BasicIntrospection.keyword_property_names
	assert_equal names, [:age, :email]
end

test "required_properties returns all required properties" do
	props = BasicIntrospection.required_properties
	assert_equal props.map(&:name), [:id, :name, :age]
	assert props.all?(&:required?)
end

test "required_property_names returns all required property names" do
	names = BasicIntrospection.required_property_names
	assert_equal names, [:id, :name, :age]
end

test "required_positional_properties returns only required positional properties" do
	props = BasicIntrospection.required_positional_properties
	assert_equal props.map(&:name), [:id, :name]
	assert props.all? { |p| p.required? && p.positional? }
end

test "required_positional_property_names returns only required positional property names" do
	names = BasicIntrospection.required_positional_property_names
	assert_equal names, [:id, :name]
end

test "required_keyword_properties returns only required keyword properties" do
	props = BasicIntrospection.required_keyword_properties
	assert_equal props.map(&:name), [:age]
	assert props.all? { |p| p.required? && p.keyword? }
end

test "required_keyword_property_names returns only required keyword property names" do
	names = BasicIntrospection.required_keyword_property_names
	assert_equal names, [:age]
end

test "optional_positional_properties returns positional properties that are not required" do
	props = WithOptionals.optional_positional_properties
	assert_equal props.map(&:name), [:optional_pos, :optional_name]
	assert props.all? { |p| p.positional? && !p.required? }
end

test "optional_positional_property_names returns optional positional property names" do
	names = WithOptionals.optional_positional_property_names
	assert_equal names, [:optional_pos, :optional_name]
end

test "optional_keyword_properties returns keyword properties that are not required" do
	props = WithOptionals.optional_keyword_properties
	assert_equal props.map(&:name), [:optional_kw, :tags, :created_at]
	assert props.all? { |p| p.keyword? && !p.required? }
end

test "optional_keyword_property_names returns optional keyword property names" do
	names = WithOptionals.optional_keyword_property_names
	assert_equal names, [:optional_kw, :tags, :created_at]
end

test "empty class returns empty arrays for all methods" do
	assert_equal EmptyWithIntrospection.positional_properties, []
	assert_equal EmptyWithIntrospection.keyword_properties, []
	assert_equal EmptyWithIntrospection.required_properties, []
	assert_equal EmptyWithIntrospection.required_positional_properties, []
	assert_equal EmptyWithIntrospection.required_keyword_properties, []
	assert_equal EmptyWithIntrospection.optional_positional_properties, []
	assert_equal EmptyWithIntrospection.optional_keyword_properties, []

	assert_equal EmptyWithIntrospection.positional_property_names, []
	assert_equal EmptyWithIntrospection.keyword_property_names, []
	assert_equal EmptyWithIntrospection.required_property_names, []
	assert_equal EmptyWithIntrospection.required_positional_property_names, []
	assert_equal EmptyWithIntrospection.required_keyword_property_names, []
	assert_equal EmptyWithIntrospection.optional_positional_property_names, []
	assert_equal EmptyWithIntrospection.optional_keyword_property_names, []
end

test "splat parameters are not included in positional or keyword properties" do
	positional_names = BasicIntrospection.positional_property_names
	refute positional_names.include?(:friends)

	keyword_names = BasicIntrospection.keyword_property_names
	refute keyword_names.include?(:options)
end

test "block parameters are not included in any property lists" do
	all_names = BasicIntrospection.positional_property_names + BasicIntrospection.keyword_property_names
	refute all_names.include?(:block)
end

test "nilable positional properties are considered optional" do
	required_names = WithOptionals.required_positional_property_names
	optional_names = WithOptionals.optional_positional_property_names

	assert_equal required_names, [:required_pos]
	assert_equal optional_names, [:optional_pos, :optional_name]
end

test "mixed property types with defaults and nilables" do
	assert_equal WithOptionals.positional_property_names, [:required_pos, :optional_pos, :optional_name]
	assert_equal WithOptionals.keyword_property_names, [:required_kw, :optional_kw, :tags, :created_at]
	assert_equal WithOptionals.required_positional_property_names, [:required_pos]
	assert_equal WithOptionals.required_keyword_property_names, [:required_kw]
	assert_equal WithOptionals.optional_positional_property_names, [:optional_pos, :optional_name]
	assert_equal WithOptionals.optional_keyword_property_names, [:optional_kw, :tags, :created_at]
end

test "property_descriptions returns hash of all property names to descriptions" do
	descriptions = BasicIntrospection.property_descriptions

	assert_equal descriptions, {
		id: "Unique identifier",
		name: nil,
		age: "Age in years",
		email: nil,
		friends: nil,
		options: nil,
		block: nil,
	}
end

test "described_properties returns only properties with descriptions" do
	props = BasicIntrospection.described_properties
	assert_equal props.map(&:name), [:id, :age]
	assert props.all?(&:description?)
end

test "described_property_names returns names of properties with descriptions" do
	names = BasicIntrospection.described_property_names
	assert_equal names, [:id, :age]
end

test "empty class returns empty results for description methods" do
	assert_equal EmptyWithIntrospection.property_descriptions, {}
	assert_equal EmptyWithIntrospection.described_properties, []
	assert_equal EmptyWithIntrospection.described_property_names, []
end
