# frozen_string_literal: true

require "set"
require "js_regex"

include Literal::Types

class SerializationPerson < Literal::Data
	prop :name, String
	prop :age, Integer
end

class SerializationPost < Literal::Data
	prop :title, String
	prop :subtitle, _Nilable(String)
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
	Literal::MapSerializer,
	Literal::TupleSerializer,
	Literal::ArraySerializer,
	Literal::SetSerializer,
	Literal::NilableSerializer,
)

test "string length range serialization" do
	assert_equal(
		Example.json_schema(_String(length: 1..)),
		{ "type" => "string", "minLength" => 1 },
	)

	assert_equal(
		Example.json_schema(_String(length: ..10)),
		{ "type" => "string", "maxLength" => 10 },
	)

	assert_equal(
		Example.json_schema(_String(length: ...10)),
		{ "type" => "string", "maxLength" => 9 },
	)
end

test "string regex pattern serialization" do
	assert_equal(
		Example.json_schema(_String(/\A[A-Z]+\z/)),
		{ "type" => "string", "pattern" => "/^[A-Z]+$/" },
	)
end

test "json schema scalar type serialization" do
	assert_equal(
		Example.json_schema(Literal::JSONSchema::String(format: "email", min_length: 1)),
		{ "type" => "string", "format" => "email", "minLength" => 1 },
	)

	assert_equal(
		Example.json_schema(Literal::JSONSchema::Integer(minimum: 0, exclusive_maximum: 10)),
		{ "type" => "integer", "minimum" => 0, "exclusiveMaximum" => 10 },
	)

	assert_equal(
		Example.json_schema(Literal::JSONSchema::Number(exclusive_minimum: 0, maximum: 1.5)),
		{ "type" => "number", "exclusiveMinimum" => 0, "maximum" => 1.5 },
	)
end

test "array length range serialization" do
	assert_equal(
		Example.json_schema(_Constraint(_Array(String), length: 5..10)),
		{
			"type" => "array",
			"items" => { "type" => "string" },
			"minItems" => 5,
			"maxItems" => 10,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Array(String), size: 1...10)),
		{
			"type" => "array",
			"items" => { "type" => "string" },
			"minItems" => 1,
			"maxItems" => 9,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Array(String), length: 1..)),
		{
			"type" => "array",
			"items" => { "type" => "string" },
			"minItems" => 1,
		},
	)
end

test "set length range serialization" do
	assert_equal(
		Example.json_schema(_Constraint(_Set(String), length: 5..10)),
		{
			"type" => "array",
			"uniqueItems" => true,
			"items" => { "type" => "string" },
			"minItems" => 5,
			"maxItems" => 10,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Set(String), size: 1...10)),
		{
			"type" => "array",
			"uniqueItems" => true,
			"items" => { "type" => "string" },
			"minItems" => 1,
			"maxItems" => 9,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Set(String), length: 1..)),
		{
			"type" => "array",
			"uniqueItems" => true,
			"items" => { "type" => "string" },
			"minItems" => 1,
		},
	)
end

test "boolean json schema" do
	assert_equal(
		Example.json_schema(_Boolean),
		{ "type" => "boolean" },
	)
end

test "integer json schema" do
	assert_equal(
		Example.json_schema(Integer),
		{ "type" => "integer" },
	)

	assert_equal(
		Example.json_schema(42),
		{ "type" => "integer", "const" => 42 },
	)

	assert_equal(
		Example.json_schema(_Integer(5..10)),
		{ "type" => "integer", "minimum" => 5, "maximum" => 10 },
	)

	assert_equal(
		Example.json_schema(_Integer(5...10)),
		{ "type" => "integer", "minimum" => 5, "exclusiveMaximum" => 10 },
	)

	assert_equal(
		Example.json_schema(_Integer(5..)),
		{ "type" => "integer", "minimum" => 5 },
	)
end

test "float json schema" do
	assert_equal(
		Example.json_schema(Float),
		{ "type" => "number" },
	)

	assert_equal(
		Example.json_schema(3.14),
		{ "type" => "number", "const" => 3.14 },
	)

	assert_equal(
		Example.json_schema(_Float(1.5..3.5)),
		{ "type" => "number", "minimum" => 1.5, "maximum" => 3.5 },
	)

	assert_equal(
		Example.json_schema(_Union(1.5, 2.5, 3.5)),
		{ "type" => "number", "enum" => [1.5, 2.5, 3.5] },
	)
end

test "symbol json schema" do
	assert_equal(
		Example.json_schema(Symbol),
		{ "type" => "string" },
	)

	assert_equal(
		Example.json_schema(:active),
		{ "type" => "string", "const" => "active" },
	)

	assert_equal(
		Example.json_schema(_Symbol(size: 5..10)),
		{ "type" => "string", "minLength" => 5, "maxLength" => 10 },
	)

	assert_equal(
		Example.json_schema(_Union(:small, :medium, :large)),
		{
			"type" => "string",
			"enum" => ["small", "medium", "large"],
		},
	)

	assert_equal(
		Example.json_schema(_Union(Symbol, _Symbol(size: 5..10))),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "symbol:0" },
						"value" => { "type" => "string" },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "symbol:1" },
						"value" => { "type" => "string", "minLength" => 5, "maxLength" => 10 },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "date json schema" do
	assert_equal(
		Example.json_schema(Date),
		{ "type" => "string", "format" => "date" },
	)

	assert_equal(
		Example.json_schema(Date.new(2025, 1, 13)),
		{ "type" => "string", "format" => "date", "const" => "2025-01-13" },
	)

	assert_equal(
		Example.json_schema(_Date((Date.new(2025, 1, 1))..(Date.new(2025, 12, 31)))),
		{
			"type" => "string",
			"format" => "date",
			"minimum" => "2025-01-01",
			"maximum" => "2025-12-31",
		},
	)

	assert_equal(
		Example.json_schema(_Date((Date.new(2025, 1, 1))...(Date.new(2026, 1, 1)))),
		{
			"type" => "string",
			"format" => "date",
			"minimum" => "2025-01-01",
			"exclusiveMaximum" => "2026-01-01",
		},
	)

	assert_equal(
		Example.json_schema(_Date((Date.new(2025, 1, 1))..)),
		{
			"type" => "string",
			"format" => "date",
			"minimum" => "2025-01-01",
		},
	)
end

test "hash json schema" do
	assert_equal(
		Example.json_schema(_Hash(Symbol, Integer)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string" },
			"additionalProperties" => { "type" => "integer" },
		},
	)

	assert_equal(
		Example.json_schema(_Hash(_Union(:small, :large), String)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string", "enum" => ["small", "large"] },
			"additionalProperties" => { "type" => "string" },
		},
	)

	assert_equal(
		Example.json_schema(_Hash(Integer, String)),
		{
			"type" => "array",
			"items" => {
				"type" => "array",
				"prefixItems" => [
					{ "type" => "integer" },
					{ "type" => "string" },
				],
				"minItems" => 2,
				"maxItems" => 2,
			},
		},
	)
end

test "map json schema" do
	assert_equal(
		Example.json_schema(_Map(name: String, age: Integer, nickname: _Nilable(String))),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"age" => { "type" => "integer" },
				"nickname" => {
					"anyOf" => [
						{ "type" => "string" },
						{ "type" => "null" },
					],
				},
			},
			"required" => ["name", "age"],
			"additionalProperties" => false,
		},
	)
end

test "tuple json schema" do
	assert_equal(
		Example.json_schema(_Tuple(String, Integer, _Nilable(Symbol))),
		{
			"type" => "array",
			"prefixItems" => [
				{ "type" => "string" },
				{ "type" => "integer" },
				{
					"anyOf" => [
						{ "type" => "string" },
						{ "type" => "null" },
					],
				},
			],
			"minItems" => 3,
			"maxItems" => 3,
		},
	)
end

test "nilable json schema" do
	assert_equal(
		Example.json_schema(_Nilable(Integer)),
		{
			"anyOf" => [
				{ "type" => "integer" },
				{ "type" => "null" },
			],
		},
	)
end

test "structure json schema" do
	assert_equal(
		Example.json_schema(SerializationPerson),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"age" => { "type" => "integer" },
			},
			"required" => ["name", "age"],
			"additionalProperties" => false,
		},
	)

	assert_equal(
		Example.json_schema(SerializationPost),
		{
			"type" => "object",
			"properties" => {
				"title" => { "type" => "string" },
				"subtitle" => {
					"anyOf" => [
						{ "type" => "string" },
						{ "type" => "null" },
					],
				},
			},
			"required" => ["title"],
			"additionalProperties" => false,
		},
	)
end

test "tagged union json schema" do
	assert_equal(
		Example.json_schema(_TaggedUnion(person: SerializationPerson, note: String)),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "person" },
						"value" => {
							"type" => "object",
							"properties" => {
								"name" => { "type" => "string" },
								"age" => { "type" => "integer" },
							},
							"required" => ["name", "age"],
							"additionalProperties" => false,
						},
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "note" },
						"value" => { "type" => "string" },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "union json schema" do
	assert_equal(
		Example.json_schema(_Union("small", "medium", "large")),
		{
			"type" => "string",
			"enum" => ["small", "medium", "large"],
		},
	)

	assert_equal(
		Example.json_schema(_Union(String, Integer)),
		{
			"anyOf" => [
				{ "type" => "string" },
				{ "type" => "integer" },
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union(String, _String(length: 1..))),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "string:0" },
						"value" => { "type" => "string" },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "string:1" },
						"value" => { "type" => "string", "minLength" => 1 },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union("small", _String(length: 1..))),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "string:0" },
						"value" => { "type" => "string", "const" => "small" },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "string:1" },
						"value" => { "type" => "string", "minLength" => 1 },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union(1, 2, 3)),
		{
			"type" => "integer",
			"enum" => [1, 2, 3],
		},
	)

	assert_equal(
		Example.json_schema(_Union(Integer, _Integer(5..10))),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "integer:0" },
						"value" => { "type" => "integer" },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => "integer:1" },
						"value" => { "type" => "integer", "minimum" => 5, "maximum" => 10 },
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

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

test "map serialization roundtrip" do
	original = { name: "Joel", age: 42, nickname: nil }
	type = _Map(name: String, age: Integer, nickname: _Nilable(String))
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "name" => "Joel", "age" => 42, "nickname" => nil })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "tuple serialization roundtrip" do
	original = ["Joel", 42, :admin]
	type = _Tuple(String, Integer, Symbol)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, ["Joel", 42, "admin"])
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

	assert_equal(name_serialized, { "type" => "name", "value" => "Joel" })
	assert_equal(age_serialized, { "type" => "age", "value" => 42 })
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "implicit nil serialization" do
	type = Example.type
	assert_equal nil, Example.serialize(nil, type:)
end

test "implicit string serialization" do
	type = Example.type
	assert_equal({ "type" => "string", "value" => "example" }, Example.serialize("example", type:))
end

test "implicit symbol serialization" do
	type = Example.type
	assert_equal({ "type" => "symbol", "value" => "example" }, Example.serialize(:example, type:))
end

test "implicit integer serialization" do
	type = Example.type
	assert_equal({ "type" => "integer", "value" => 42 }, Example.serialize(42, type:))
end

test "implicit float serialization" do
	type = Example.type
	assert_equal({ "type" => "float", "value" => 3.14 }, Example.serialize(3.14, type:))
end

test "implicit boolean serialization" do
	type = Example.type
	assert_equal({ "type" => "boolean", "value" => true }, Example.serialize(true, type:))
end

test "implicit date serialization" do
	type = Example.type
	assert_equal({ "type" => "date", "value" => "2025-01-13" }, Example.serialize(Date.new(2025, 1, 13), type:))
end

test "implicit array serialization" do
	type = Example.type
	value = [1, 2, 3]

	assert_equal(
		{
			"type" => "array",
			"value" => [
				{ "type" => "integer", "value" => 1 },
				{ "type" => "integer", "value" => 2 },
				{ "type" => "integer", "value" => 3 },
			],
		},
		Example.serialize(value, type:),
	)
end

test "implicit set serialization" do
	type = Example.type
	value = Set[1, 2, 3]

	assert_equal(
		{
			"type" => "set",
			"value" => [
				{ "type" => "integer", "value" => 1 },
				{ "type" => "integer", "value" => 2 },
				{ "type" => "integer", "value" => 3 },
			],
		},
		Example.serialize(value, type:),
	)
end

test "implicit hash serialization" do
	type = Example.type
	value = { a: 1, b: 2 }

	assert_equal(
		{
			"type" => "hash",
			"value" => [
				[
					{ "type" => "symbol", "value" => "a" },
					{ "type" => "integer", "value" => 1 },
				],
				[
					{ "type" => "symbol", "value" => "b" },
					{ "type" => "integer", "value" => 2 },
				],
			],
		},
		Example.serialize(value, type:),
	)
	assert_equal value, Example.deserialize(Example.serialize(value, type:), type:)
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
	assert Example.kind === _Tuple(Example.type, String)
	assert Example.kind === _Set(Example.type)
end

test "union serialization roundtrip" do
	type = _Union(String, Integer)
	name_original = "Joel"
	age_original = 42

	name_serialized = Example.serialize(name_original, type:)
	age_serialized = Example.serialize(age_original, type:)

	assert_equal(name_serialized, "Joel")
	assert_equal(age_serialized, 42)
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "discriminated union serialization roundtrip" do
	type = _Union(String, _String(length: 1..))
	original = "Joel"
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "type" => "string:0", "value" => "Joel" })
	assert_equal(Example.deserialize(serialized, type:), original)
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
			"primary" => ["active", 1, nil],
			"secondary" => [2, "backup"],
		},
		"schedule" => ["2025-01-13", "2025-01-20"],
		"choice" => { "type" => "person", "value" => { "name" => "Jill", "age" => 40 } },
		"payload" => { "type" => "hash", "value" => { "count" => 3, "total" => 9 } },
	})

	assert_equal(Example.deserialize(serialized, type:), original)
end
