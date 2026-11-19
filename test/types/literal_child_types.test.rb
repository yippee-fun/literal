# frozen_string_literal: true

include Literal::Types

test "default literal child types" do
	assert_equal _Any.literal_child_types.to_a, []
end

test "single child literal types" do
	assert_equal _Array(String).literal_child_types.to_a, [String]
	assert_equal _Enumerable(String).literal_child_types.to_a, [String]
	assert_equal _Frozen(String).literal_child_types.to_a, [String]
	assert_equal _Kind(String).literal_child_types.to_a, [String]
	assert_equal _Nilable(String).literal_child_types.to_a, [String]
	assert_equal _Not(String).literal_child_types.to_a, [String]
	assert_equal _Range(String).literal_child_types.to_a, [String]
	assert_equal _Set(String).literal_child_types.to_a, [String]
end

test "compound literal child types" do
	assert_equal _Hash(Symbol, Integer).literal_child_types.to_a, [Symbol, Integer]
	assert_equal _Map(name: String, age: Integer).literal_child_types.to_a, [String, Integer]
	assert_equal _Tuple(String, Integer).literal_child_types.to_a, [String, Integer]
	assert_equal _Union(String, Integer, "literal").literal_child_types.to_a, [String, Integer]
	assert_equal _TaggedUnion(name: String, age: Integer).literal_child_types.to_a, [String, Integer]
end

test "constraint literal child types" do
	assert_equal _Constraint(String, 1..10, size: 1..5).literal_child_types.to_a, [String, 1..10, 1..5]
end

test "deferred literal child types" do
	type = _Deferred { String }

	assert_equal type.literal_child_types.to_a, [String]
end

test "data structure literal child types" do
	data = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
	end

	struct = Class.new(Literal::Struct) do
		prop :name, String
		prop :age, Integer
	end

	assert_equal data.literal_child_types.to_a, [String, Integer]
	assert_equal struct.literal_child_types.to_a, [String, Integer]
end
