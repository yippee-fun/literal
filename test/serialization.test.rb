# frozen_string_literal: true

require "set"

include Literal::Types

class SerializationPerson < Literal::Data
	prop :name, String
	prop :age, Integer
end

class SerializationEnvelope < Literal::Data
	prop :id, Integer
	prop :owner, SerializationPerson
	prop :tags, _Set(Symbol)
	prop :metadata, _Hash(Symbol, _Array(_Nilable(_Union(String, Integer))))
	prop :schedule, _Array(Date)
	prop :choice, _TaggedUnion(person: SerializationPerson, note: String)
	prop :payload, _Union(_Hash(Symbol, Integer), _Array(String))
end

Example = Literal::SerializationContext.new(
	Literal::StringSerializer,
	Literal::SymbolSerializer,
	Literal::IntegerSerializer,
	Literal::FloatSerializer,
	Literal::BooleanSerializer,
	Literal::DateSerializer,
	Literal::StructureSerializer,
	Literal::TaggedUnionSerializer,
	Literal::UnionSerializer,
	Literal::HashSerializer,
	Literal::ArraySerializer,
	Literal::SetSerializer,
	Literal::NilableSerializer,
)

test "array serialization roundtrip" do
	original = [1, 2, 3]
	type = _Array(Integer)
	serialized = Example.serialize([1, 2, 3], type:)

	assert_equal(serialized, [1, 2, 3])
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "integer serialization roundtrip" do
	original = 42
	type = Integer
	serialized = Example.serialize(42, type:)

	assert_equal(serialized, 42)
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "string serialization roundtrip" do
	original = "example"
	type = String
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "example")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "symbol serialization roundtrip" do
	original = :example
	type = Symbol
	serialized = Example.serialize(:example, type:)

	assert_equal(serialized, "example")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "boolean serialization roundtrip" do
	original = true
	type = _Boolean
	serialized = Example.serialize(true, type:)

	assert_equal(serialized, true)
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "date serialization roundtrip" do
	original = Date.new(2025, 1, 13)
	type = Date
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "2025-01-13")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "float serialization roundtrip" do
	original = 3.14
	type = Float
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, 3.14)
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "hash serialization roundtrip" do
	original = { foo: 1, bar: 2 }
	type = _Hash(Symbol, Integer)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "foo" => 1, "bar" => 2 })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "nilable serialization roundtrip" do
	type = _Nilable(Integer)
	non_nil = 42
	non_nil_serialized = Example.serialize(non_nil, type:)
	nil_serialized = Example.serialize(nil, type:)

	assert_equal(non_nil_serialized, 42)
	assert_equal(Example.deserialize(non_nil_serialized, type:), non_nil)
	assert_equal(nil_serialized, nil)
	assert_equal(Example.deserialize(nil_serialized, type:), nil)
end

test "set serialization roundtrip" do
	original = Set[1, 2, 3]
	type = _Set(Integer)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, [1, 2, 3])
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "structure serialization roundtrip" do
	original = SerializationPerson.new(name: "Joel", age: 42)
	type = SerializationPerson
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "name" => "Joel", "age" => 42 })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "tagged union serialization roundtrip" do
	type = _TaggedUnion(name: String, age: Integer)
	name_original = "Joel"
	age_original = 42

	name_serialized = Example.serialize(name_original, type:)
	age_serialized = Example.serialize(age_original, type:)

	assert_equal(name_serialized, ["name", "Joel"])
	assert_equal(age_serialized, ["age", 42])
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "implicit nil serialization" do
	type = Example.type
	assert_equal nil, Example.serialize(nil, type:)
end

test "implicit string serialization" do
	type = Example.type
	assert_equal ["string", "example"], Example.serialize("example", type:)
end

test "implicit symbol serialization" do
	type = Example.type
	assert_equal ["symbol", "example"], Example.serialize(:example, type:)
end

test "implicit integer serialization" do
	type = Example.type
	assert_equal ["integer", 42], Example.serialize(42, type:)
end

test "implicit float serialization" do
	type = Example.type
	assert_equal ["float", 3.14], Example.serialize(3.14, type:)
end

test "implicit boolean serialization" do
	type = Example.type
	assert_equal ["boolean", true], Example.serialize(true, type:)
end

test "implicit date serialization" do
	type = Example.type
	assert_equal ["date", "2025-01-13"], Example.serialize(Date.new(2025, 1, 13), type:)
end

test "implicit array serialization" do
	type = Example.type
	value = [1, 2, 3]

	assert_equal ["array", [["integer", 1], ["integer", 2], ["integer", 3]]], Example.serialize(value, type:)
end

test "implicit set serialization" do
	type = Example.type
	value = Set[1, 2, 3]

	assert_equal ["set", [["integer", 1], ["integer", 2], ["integer", 3]]], Example.serialize(value, type:)
end

test "implicit branch precedence" do
	tag, type = Example.type.resolve(nil)
	assert_equal :nilable, tag
	assert_equal "_Nilable(_Deferred)", type.inspect

	tag, type = Example.type.resolve([1, 2, 3])
	assert_equal :array, tag
	assert_equal "_Array(_Deferred)", type.inspect

	tag, type = Example.type.resolve(Set[1, 2, 3])
	assert_equal :set, tag
	assert_equal "_Set(_Deferred)", type.inspect
end

test "recursive kind support" do
	assert Example.kind === Example.type
	assert Example.kind === _Union(Example.type, String)
	assert Example.kind === _TaggedUnion(foo: Example.type, bar: String)
	assert Example.kind === _Array(Example.type)
	assert Example.kind === _Set(Example.type)
end

test "union serialization roundtrip" do
	type = _Union(String, Integer)
	name_original = "Joel"
	age_original = 42

	name_serialized = Example.serialize(name_original, type:)
	age_serialized = Example.serialize(age_original, type:)

	assert_equal(name_serialized, ["string", "Joel"])
	assert_equal(age_serialized, ["integer", 42])
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "big nested serialization roundtrip" do
	original = SerializationEnvelope.new(
		id: 7,
		owner: SerializationPerson.new(name: "Joel", age: 42),
		tags: Set[:admin, :staff],
		metadata: {
			primary: ["active", 1, nil],
			secondary: [2, "backup"],
		},
		schedule: [Date.new(2025, 1, 13), Date.new(2025, 1, 20)],
		choice: SerializationPerson.new(name: "Jill", age: 40),
		payload: { count: 3, total: 9 },
	)

	type = SerializationEnvelope
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, {
		"id" => 7,
		"owner" => {
			"name" => "Joel",
			"age" => 42,
		},
		"tags" => ["admin", "staff"],
		"metadata" => {
			"primary" => [["string", "active"], ["integer", 1], nil],
			"secondary" => [["integer", 2], ["string", "backup"]],
		},
		"schedule" => ["2025-01-13", "2025-01-20"],
		"choice" => ["person", { "name" => "Jill", "age" => 40 }],
		"payload" => ["hash", { "count" => 3, "total" => 9 }],
	})

	assert_equal(Example.deserialize(serialized, type:), original)
end
