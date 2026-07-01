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

class SerializationArticle < Literal::Data
	prop :title, String, description: "Published headline"
	prop :body, String
end

class SerializationValueObject < Literal::Data
	prop :value, String
end

class SerializationBooleanConst < Literal::Data
	prop :foo, true
end

class SerializationDraft < Literal::Data
	prop :title, String
	prop? :subtitle, String
end

class SerializationEnvelope < Literal::Data
	prop :id, Integer
	prop :owner, SerializationPerson
	prop :tags, _Set(Symbol)
	prop :metadata, _Hash(Symbol, _Array(_Nilable(_Union(String, Integer))))
	prop :schedule, _Array(Date)
	prop :choice, _TaggedUnion(person: SerializationPerson, note: String)
	prop :payload, _TaggedUnion(hash: _Hash(Symbol, Integer), array: _Array(String))
end

Example = Literal::SerializationContext.new(
	Literal::StringSerializer,
	Literal::SymbolSerializer,
	Literal::IntegerSerializer,
	Literal::JSONSchemaNumberSerializer,
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

	assert_equal(
		Example.json_schema(_String(size: 2..4)),
		{ "type" => "string", "minLength" => 2, "maxLength" => 4 },
	)
end

test "string regex pattern serialization" do
	assert_equal(
		Example.json_schema(_String(/\A[A-Z]+\z/)),
		{ "type" => "string", "pattern" => "^[A-Z]+$" },
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

	assert_equal(
		Example.json_schema(true),
		{ "type" => "boolean", "const" => true },
	)

	assert_equal(
		Example.json_schema(false),
		{ "type" => "boolean", "const" => false },
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
		Example.json_schema(_Float(finite?: true)),
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
			"anyOf" => [
				{ "type" => "string" },
				{ "type" => "string", "minLength" => 5, "maxLength" => 10 },
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
		{ "type" => "string", "format" => "date" },
	)

	assert_equal(
		Example.json_schema(_Date((Date.new(2025, 1, 1))...(Date.new(2026, 1, 1)))),
		{ "type" => "string", "format" => "date" },
	)

	assert_equal(
		Example.json_schema(_Date((Date.new(2025, 1, 1))..)),
		{ "type" => "string", "format" => "date" },
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
		Example.json_schema(_Hash(_String(/\A[a-z_]+\z/), Integer)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string", "pattern" => "^[a-z_]+$" },
			"additionalProperties" => { "type" => "integer" },
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

	assert_equal(
		Example.json_schema(_Constraint(_Hash(Symbol, Integer), size: 1..5)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string" },
			"additionalProperties" => { "type" => "integer" },
			"minProperties" => 1,
			"maxProperties" => 5,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Hash(Symbol, Integer), length: 1...5)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string" },
			"additionalProperties" => { "type" => "integer" },
			"minProperties" => 1,
			"maxProperties" => 4,
		},
	)

	assert_equal(
		Example.json_schema(_Constraint(_Hash(Integer, String), size: 2)),
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
			"minItems" => 2,
			"maxItems" => 2,
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

	assert_equal(
		Example.json_schema(SerializationArticle),
		{
			"type" => "object",
			"properties" => {
				"title" => { "type" => "string", "description" => "Published headline" },
				"body" => { "type" => "string" },
			},
			"required" => ["title", "body"],
			"additionalProperties" => false,
		},
	)

	assert_equal(
		Example.json_schema(SerializationDraft),
		{
			"type" => "object",
			"properties" => {
				"title" => { "type" => "string" },
				"subtitle" => { "type" => "string" },
			},
			"required" => ["title"],
			"additionalProperties" => false,
		},
	)

	assert_equal(
		Example.json_schema(SerializationBooleanConst),
		{
			"type" => "object",
			"properties" => {
				"foo" => { "type" => "boolean", "const" => true },
			},
			"required" => ["foo"],
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
						"$type" => { "const" => "person" },
						"name" => { "type" => "string" },
						"age" => { "type" => "integer" },
					},
					"required" => ["$type", "name", "age"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"$type" => { "const" => "note" },
						"value" => { "type" => "string" },
					},
					"required" => ["$type", "value"],
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
			"oneOf" => [
				{ "type" => "string" },
				{ "type" => "integer" },
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union(nil, String)),
		{
			"oneOf" => [
				{ "type" => "null" },
				{ "type" => "string" },
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union(String, _String(length: 1..))),
		{
			"anyOf" => [
				{ "type" => "string" },
				{ "type" => "string", "minLength" => 1 },
			],
		},
	)

	assert_equal(
		Example.json_schema(_Union("small", _String(length: 1..))),
		{
			"anyOf" => [
				{ "type" => "string", "const" => "small" },
				{ "type" => "string", "minLength" => 1 },
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
			"anyOf" => [
				{ "type" => "integer" },
				{ "type" => "integer", "minimum" => 5, "maximum" => 10 },
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
	type = _Float(finite?: true)
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

test "hash serialization shape follows key type schema" do
	type = _Hash(_Union(String, Integer), String)

	assert_equal(Example.serialize({ "foo" => "bar" }, type:), [["foo", "bar"]])
	assert_equal(Example.serialize({ 1 => "bar" }, type:), [[1, "bar"]])
end

test "map serialization roundtrip" do
	original = { name: "Joel", age: 42, nickname: nil }
	type = _Map(name: String, age: Integer, nickname: _Nilable(String))
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "name" => "Joel", "age" => 42, "nickname" => nil })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "map with type key serialization roundtrip" do
	original = { "$type": "user", name: "Joel" }
	type = _Map("$type": String, name: String)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "$type" => "user", "name" => "Joel" })
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

test "optional structure property serialization roundtrip" do
	type = SerializationDraft
	without_subtitle = SerializationDraft.new(title: "Draft")
	with_subtitle = SerializationDraft.new(title: "Draft", subtitle: "Optional")

	assert_equal(Example.serialize(without_subtitle, type:), { "title" => "Draft" })
	assert_equal(Example.serialize(with_subtitle, type:), { "title" => "Draft", "subtitle" => "Optional" })
	assert_equal(Example.deserialize({ "title" => "Draft" }, type:), without_subtitle)
	assert_equal(Example.deserialize({ "title" => "Draft", "subtitle" => "Optional" }, type:), with_subtitle)
end

test "tagged union serialization roundtrip" do
	type = _TaggedUnion(name: String, age: Integer)
	name_original = "Joel"
	age_original = 42

	name_serialized = Example.serialize(name_original, type:)
	age_serialized = Example.serialize(age_original, type:)

	assert_equal(name_serialized, { "$type" => "name", "value" => "Joel" })
	assert_equal(age_serialized, { "$type" => "age", "value" => 42 })
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "tagged union object with value property serialization roundtrip" do
	type = _TaggedUnion(object: SerializationValueObject, note: String)
	original = SerializationValueObject.new(value: "payload")
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "value" => "payload", "$type" => "object" })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "tagged union hash with type key serialization roundtrip" do
	type = _TaggedUnion(hash: _Hash(String, String), integer: Integer)
	original = { "$type" => "user", "name" => "Joel" }
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "$type" => "hash", "value" => { "$type" => "user", "name" => "Joel" } })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "tagged union map with type key serialization roundtrip" do
	type = _TaggedUnion(map: _Map("$type": String, name: String), integer: Integer)
	original = { "$type": "user", name: "Joel" }
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "$type" => "map", "value" => { "$type" => "user", "name" => "Joel" } })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "serialization context type matches serializable values" do
	assert Example.type === nil
	assert Example.type === "example"
	assert Example.type === :example
	assert Example.type === 42
	assert Example.type === 3.14
	assert Example.type === true
	assert Example.type === Date.new(2025, 1, 13)
	assert Example.type === [1, 2, 3]
	assert Example.type === Set[1, 2, 3]
	assert Example.type === { a: 1, b: 2 }
end

test "recursive kind support" do
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

	assert_equal(name_serialized, "Joel")
	assert_equal(age_serialized, 42)
	assert_equal(Example.deserialize(name_serialized, type:), name_original)
	assert_equal(Example.deserialize(age_serialized, type:), age_original)
end

test "natural union number deserialization accepts integers" do
	type = _Union(_Float(finite?: true), String)

	assert_equal(Example.deserialize(1, type:), 1.0)
end

test "string and date union is not naturally discriminated" do
	type = _Union(String, Date)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "integer and number union is not naturally discriminated" do
	type = _Union(Integer, _Float(finite?: true))

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "same-kind union serialization roundtrip" do
	type = _Union(String, _String(length: 1..))
	original = "Joel"
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "Joel")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "non-natural union object is not serializable" do
	type = _Union(SerializationValueObject, String)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "non-natural union hash is not serializable" do
	type = _Union(_Hash(String, String), Integer)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "non-natural union map is not serializable" do
	type = _Union(_Map("$type": String, name: String), Integer)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
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
		"choice" => { "$type" => "person", "name" => "Jill", "age" => 40 },
		"payload" => { "$type" => "hash", "value" => { "count" => 3, "total" => 9 } },
		})

	assert_equal(Example.deserialize(serialized, type:), original)
end
