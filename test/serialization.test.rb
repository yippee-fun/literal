# frozen_string_literal: true

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

class SerializationLabel < Literal::Data
	prop :value, String
end

class SerializationNamed < Literal::Data
	prop :name, String
end

class SerializationTitled < Literal::Data
	prop :title, String
end

class SerializationUserEvent < Literal::Data
	prop :kind, "user"
	prop :name, String
end

class SerializationAdminEvent < Literal::Data
	prop :kind, "admin"
	prop :name, String
end

class SerializationBooleanConst < Literal::Data
	prop :foo, true
end

class SerializationPoint < Literal::Data
	prop :x, Integer, :positional
	prop :y, Integer, :positional
	prop :label, String
end

class SerializationLeveled < Literal::Data
	prop :name, String
	prop :level, Integer, default: 3
end

class SerializationCoerced < Literal::Data
	prop :date, Date do |value|
		Date.parse(value)
	end
end

class SerializationDraft < Literal::Data
	prop :title, String
	prop? :subtitle, String
end

class SerializationOrder < Literal::Data
	prop :id, Integer
	prop :person, SerializationPerson
end

class SerializationTeam < Literal::Data
	prop :lead, SerializationPerson
	prop :backup, SerializationPerson
end

SerializationRecursiveAddress = Class.new(Literal::Data) do
	prop :postcode, String
end

SerializationRecursiveOrder = Class.new(Literal::Data) do
	prop :id, Integer
	prop :address, SerializationRecursiveAddress
end

SerializationRecursiveAddress.prop :order, SerializationRecursiveOrder

class SerializationRecursiveNode < Literal::Data
	prop :children, _Array(_Deferred { SerializationRecursiveNode })
end

class SerializationUnsupportedRecursiveNode < Literal::Data
	prop :children, _Array(_Deferred { SerializationUnsupportedRecursiveNode })
	prop :object, Object
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

class SerializationSecret < Literal::Data
	prop :name, String
	prop :secret, String
end

class SerializationRedactingSerializer < Literal::Serializer
	def type
		SerializationSecret
	end

	def child_types(type)
		super_serializer(type).child_types(type)
	end

	def object_shape(type)
		super_serializer(type).object_shape(type)
	end

	def json_schema(type, generator: nil)
		super_json_schema(type, generator:)
	end

	def serialize(value, type:)
		super_serialize(value, type:).merge("secret" => "[redacted]")
	end

	def deserialize(raw, type:)
		super_deserialize(raw, type:)
	end
end

class SerializationUpcasingSerializer < SerializationRedactingSerializer
	def serialize(value, type:)
		serialized = super_serialize(value, type:)
		serialized.merge("name" => serialized.fetch("name").upcase)
	end
end

SerializationOpaque = Class.new

class SerializationOpaqueSerializer < Literal::Serializer
	def type
		SerializationOpaque
	end

	def serialize(value, type:)
		super_serialize(value, type:)
	end
end

class SerializationMoney
	attr_reader :cents, :currency

	def initialize(cents, currency)
		@cents = cents
		@currency = currency
	end

	def ==(other)
		self.class === other && cents == other.cents && currency == other.currency
	end
end

class SerializationMoneyCodec < Literal::Serializer::Codec
	def type
		SerializationMoney
	end

	def encoded_type
		_Map(cents: Integer, currency: String)
	end

	def encode(value)
		{ cents: value.cents, currency: value.currency }
	end

	def decode(value)
		SerializationMoney.new(value[:cents], value[:currency])
	end
end

class SerializationSpan
	attr_reader :range

	def initialize(range)
		@range = range
	end

	def ==(other)
		self.class === other && range == other.range
	end
end

class SerializationSpanCodec < Literal::Serializer::Codec
	def type
		SerializationSpan
	end

	def encoded_type
		_Map(
			from: _Nilable(Date),
			to: _Nilable(Date),
			inclusive: _Boolean,
		)
	end

	def encode(value)
		range = value.range

		{ from: range.begin, to: range.end, inclusive: !range.exclude_end? }
	end

	def decode(value)
		if value[:inclusive]
			SerializationSpan.new((value[:from])..(value[:to]))
		else
			SerializationSpan.new((value[:from])...(value[:to]))
		end
	end
end

class SerializationWallet
	attr_reader :money

	def initialize(money)
		@money = money
	end

	def ==(other)
		self.class === other && money == other.money
	end
end

class SerializationWalletCodec < Literal::Serializer::Codec
	def type
		SerializationWallet
	end

	def encoded_type
		SerializationMoney
	end

	def encode(value)
		value.money
	end

	def decode(value)
		SerializationWallet.new(value)
	end
end

class SerializationBrokenCodec < Literal::Serializer::Codec
	def type
		SerializationOpaque
	end

	def encoded_type
		_Map(value: Object)
	end

	def encode(value)
		{ value: }
	end

	def decode(value)
		value[:value]
	end
end

class SerializationPriority < Literal::Enum(Integer)
	Low = new(1)
	Medium = new(2)
	High = new(3)

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SerializationToggle < Literal::Enum(Literal::Types::BooleanType::Instance)
	On = new(true)
	Off = new(false)

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SerializationSuit < Literal::Enum(Symbol)
	Hearts = new(:hearts)
	Spades = new(:spades)

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SerializationCode < Literal::Enum(Literal::Types::UnionType.new([String, Integer]))
	Slug = new("welcome")
	Number = new(200)

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SerializationAmbiguousEnum < Literal::Enum(Literal::Types::UnionType.new([String, Date]))
	Text = new("text")

	__after_defined__ if RUBY_ENGINE == "truffleruby"
end

class SerializationTask < Literal::Data
	prop :name, String
	prop :priority, SerializationPriority
end

Example = Literal::SerializationContext.new

test "serialization context includes default serializers" do
	assert Example.kind === String
	assert Example.kind === _Hash(Symbol, _JSONData)
end

test "serialization context defaults can be disabled" do
	context = Literal::SerializationContext.new(Literal::StringSerializer, defaults: false)

	assert context.kind === String
	refute context.kind === Integer
end

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

test "json data json schema" do
	assert_equal(
		Example.json_schema(_JSONData),
		true,
	)

	assert_equal(
		Example.json_schema(_Hash(Symbol, _JSONData)),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string" },
			"additionalProperties" => true,
		},
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

test "recursive array json schema" do
	type = nil
	type = _Array(_Deferred { type })

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "array",
			"items" => { "$ref" => "#/$defs/0" },
			"$defs" => {
				"0" => {
					"type" => "array",
					"items" => { "$ref" => "#/$defs/0" },
				},
			},
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

	assert_equal(
		Example.json_schema(_Integer(1..10, 3..6)),
		{ "type" => "integer", "minimum" => 3, "maximum" => 6 },
	)

	assert_equal(
		Example.json_schema(_Integer(1..10, 3...6)),
		{ "type" => "integer", "minimum" => 3, "exclusiveMaximum" => 6 },
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
		Example.json_schema(_Float(1.5..10.5, 3.5..6.5)),
		{ "type" => "number", "minimum" => 3.5, "maximum" => 6.5 },
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

test "time and datetime json schema" do
	time = Time.new(2025, 1, 13, 20, 30, 45, "+01:00")
	datetime = DateTime.new(2025, 1, 13, 20, 30, 45, "+01:00")

	assert_equal(
		Example.json_schema(Time),
		{ "type" => "string", "format" => "date-time" },
	)

	assert_equal(
		Example.json_schema(DateTime),
		{ "type" => "string", "format" => "date-time" },
	)

	assert_equal(
		Example.json_schema(time),
		{ "type" => "string", "format" => "date-time", "const" => "2025-01-13T20:30:45+01:00" },
	)

	assert_equal(
		Example.json_schema(_Constraint(DateTime, datetime)),
		{ "type" => "string", "format" => "date-time", "const" => "2025-01-13T20:30:45+01:00" },
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

	type = nil
	type = _Hash(String, _Deferred { type })

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "object",
			"propertyNames" => { "type" => "string" },
			"additionalProperties" => { "$ref" => "#/$defs/0" },
			"$defs" => {
				"0" => {
					"type" => "object",
					"propertyNames" => { "type" => "string" },
					"additionalProperties" => { "$ref" => "#/$defs/0" },
				},
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

	assert_equal(
		Example.json_schema(_Map(name: String, profile: _Map(bio: String))),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"profile" => {
					"type" => "object",
					"properties" => {
						"bio" => { "type" => "string" },
					},
					"required" => ["bio"],
					"additionalProperties" => false,
				},
			},
			"required" => ["name", "profile"],
			"additionalProperties" => false,
		},
	)

	recursive_map = nil
	recursive_map = _Map(name: String, child: _Nilable(_Deferred { recursive_map }))

	assert_equal(
		Example.json_schema(recursive_map),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"child" => {
					"anyOf" => [
						{ "$ref" => "#/$defs/0" },
						{ "type" => "null" },
					],
				},
			},
			"required" => ["name"],
			"additionalProperties" => false,
			"$defs" => {
				"0" => {
					"type" => "object",
					"properties" => {
						"name" => { "type" => "string" },
						"child" => {
							"anyOf" => [
								{ "$ref" => "#/$defs/0" },
								{ "type" => "null" },
							],
						},
					},
					"required" => ["name"],
					"additionalProperties" => false,
				},
			},
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

	type = nil
	type = _Tuple(String, _Nilable(_Deferred { type }))

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "array",
			"prefixItems" => [
				{ "type" => "string" },
				{
					"anyOf" => [
						{ "$ref" => "#/$defs/0" },
						{ "type" => "null" },
					],
				},
			],
			"minItems" => 2,
			"maxItems" => 2,
			"$defs" => {
				"0" => {
					"type" => "array",
					"prefixItems" => [
						{ "type" => "string" },
						{
							"anyOf" => [
								{ "$ref" => "#/$defs/0" },
								{ "type" => "null" },
							],
						},
					],
					"minItems" => 2,
					"maxItems" => 2,
				},
			},
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
		Example.json_schema(SerializationOrder),
		{
			"type" => "object",
			"properties" => {
				"id" => { "type" => "integer" },
				"person" => {
					"type" => "object",
					"properties" => {
						"name" => { "type" => "string" },
						"age" => { "type" => "integer" },
					},
					"required" => ["name", "age"],
					"additionalProperties" => false,
				},
			},
			"required" => ["id", "person"],
			"additionalProperties" => false,
		},
	)

	recursive_order_schema = {
		"type" => "object",
		"properties" => {
			"id" => { "type" => "integer" },
			"address" => {
				"type" => "object",
				"properties" => {
					"postcode" => { "type" => "string" },
					"order" => { "$ref" => "#/$defs/0" },
				},
				"required" => ["postcode", "order"],
				"additionalProperties" => false,
			},
		},
		"required" => ["id", "address"],
		"additionalProperties" => false,
	}

	assert_equal(
		Example.json_schema(SerializationRecursiveOrder),
		{
			**recursive_order_schema,
			"$defs" => {
				"0" => recursive_order_schema,
			},
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

test "time serialization roundtrip" do
	original = Time.new(2025, 1, 13, 20, 30, 45.123456789r, "+01:00")
	type = Time
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "2025-01-13T20:30:45.123456789+01:00")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "datetime serialization roundtrip" do
	original = DateTime.new(2025, 1, 13, 20, 30, 45 + (123_456_789r / 1_000_000_000), "+01:00")
	type = DateTime
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "2025-01-13T20:30:45.123456789+01:00")
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

test "json data serialization roundtrip" do
	original = {
		"message" => "ok",
		"errors" => [
			{ "prop" => "name", "message" => "is required" },
		],
		"count" => 1,
		"active" => true,
		"metadata" => nil,
	}

	serialized = Example.serialize(original, type: _JSONData)

	assert_equal(serialized, original)
	assert_equal(Example.deserialize(serialized, type: _JSONData), original)
	assert_raises(Literal::ArgumentError) { Example.serialize({ prop: :name }, type: _JSONData) }
end

test "hash with json data values serialization roundtrip" do
	original = {
		name: "Joel",
		errors: [{ "prop" => "name", "message" => "is required" }],
		count: 1,
	}
	type = _Hash(Symbol, _JSONData)
	serialized = Example.serialize(original, type:)

	assert_equal(
		serialized,
		{
			"name" => "Joel",
			"errors" => [{ "prop" => "name", "message" => "is required" }],
			"count" => 1,
		},
	)
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "set serialization roundtrip" do
	original = Set[1, 2, 3]
	type = _Set(Integer)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, [1, 2, 3])
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "range serialization roundtrip" do
	original = (Date.new(2025, 1, 1))..(Date.new(2025, 12, 31))
	type = _Range(Date)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "from" => "2025-01-01", "to" => "2025-12-31", "inclusive" => true })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "exclusive, endless and beginless range serialization roundtrips" do
	type = _Range(Integer)

	exclusive = 1...10
	serialized = Example.serialize(exclusive, type:)

	assert_equal(serialized, { "from" => 1, "to" => 10, "inclusive" => false })
	assert_equal(Example.deserialize(serialized, type:), exclusive)

	endless = (1..)
	serialized = Example.serialize(endless, type:)

	assert_equal(serialized, { "from" => 1, "to" => nil, "inclusive" => true })
	assert_equal(Example.deserialize(serialized, type:), endless)

	beginless = (..10)
	serialized = Example.serialize(beginless, type:)

	assert_equal(serialized, { "from" => nil, "to" => 10, "inclusive" => true })
	assert_equal(Example.deserialize(serialized, type:), beginless)
end

test "range json schema" do
	bound = {
		"anyOf" => [
			{ "type" => "string", "format" => "date" },
			{ "type" => "null" },
		],
	}

	assert_equal(
		Example.json_schema(_Range(Date)),
		{
			"type" => "object",
			"properties" => {
				"from" => bound,
				"to" => bound,
				"inclusive" => { "type" => "boolean" },
			},
			"required" => ["from", "to", "inclusive"],
			"additionalProperties" => false,
		},
	)
end

test "range deserialization requires the inclusive key" do
	assert_raises(KeyError) do
		Example.deserialize({ "from" => 1, "to" => 5 }, type: _Range(Integer))
	end
end

test "ranges discriminate in unions through their shape" do
	type = _Union(_Range(Integer), String)

	range_serialized = Example.serialize(1..5, type:)
	string_serialized = Example.serialize("none", type:)

	assert_equal(range_serialized, { "from" => 1, "to" => 5, "inclusive" => true })
	assert_equal(string_serialized, "none")
	assert_equal(Example.deserialize(range_serialized, type:), 1..5)
	assert_equal(Example.deserialize(string_serialized, type:), "none")
end

test "ranges merge tagged union discriminators" do
	type = _TaggedUnion(span: _Range(Integer), note: String)

	serialized = Example.serialize(1..5, type:)

	assert_equal(serialized, { "from" => 1, "to" => 5, "inclusive" => true, "$type" => "span" })
	assert_equal(Example.deserialize(serialized, type:), 1..5)
end

test "constraint-wrapped range serialization roundtrip" do
	type = _Constraint(_Range(Integer), min: 1)
	serialized = Example.serialize(1..5, type:)

	assert_equal(serialized, { "from" => 1, "to" => 5, "inclusive" => true })
	assert_equal(Example.deserialize(serialized, type:), 1..5)
	assert Example.kind === type
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
	assert Example.type === { "a" => [{ "b" => true }] }
end

test "serialization context type serializes serializable values" do
	person = SerializationPerson.new(name: "Joel", age: 42)

	assert_equal(Example.serialize(nil, type: Example.type), nil)
	assert_equal(Example.serialize("example", type: Example.type), "example")
	assert_equal(Example.serialize(:example, type: Example.type), "example")
	assert_equal(Example.serialize(42, type: Example.type), 42)
	assert_equal(Example.serialize(3.14, type: Example.type), 3.14)
	assert_equal(Example.serialize(true, type: Example.type), true)
	assert_equal(Example.serialize(Date.new(2025, 1, 13), type: Example.type), "2025-01-13")
	assert_equal(Example.serialize([:a, 1, nil], type: Example.type), ["a", 1, nil])
	assert_equal(Example.serialize({ a: 1, b: :two }, type: Example.type), [["a", 1], ["b", "two"]])
	assert_equal(Example.serialize({ "a" => "b" }, type: Example.type), [["a", "b"]])
	assert_equal(Example.serialize(Set[:a, :b], type: Example.type), ["a", "b"])
	assert_equal(Example.serialize(person, type: Example.type), { "name" => "Joel", "age" => 42 })
end

test "property constraints that json schema cannot express are ignored" do
	assert_equal(
		Example.json_schema(_String(reverse: "oof", length: 3..)),
		{ "type" => "string", "minLength" => 3 },
	)

	assert_equal(
		Example.json_schema(_Constraint(_Array(String), first: "a")),
		{ "type" => "array", "items" => { "type" => "string" } },
	)

	assert_equal(Example.serialize("foo", type: _String(reverse: "oof")), "foo")
	assert_equal(Example.deserialize("foo", type: _String(reverse: "oof")), "foo")
end

test "context type rejects values whose structure type is not serializable" do
	unsupported = SerializationUnsupportedRecursiveNode.new(children: [], object: Object.new)

	refute Example.type === unsupported
	refute Example.type === [unsupported]
	refute Example.type === { key: unsupported }

	assert_raises(Literal::ArgumentError) { Example.serialize(unsupported, type: Example.type) }
	assert_raises(Literal::ArgumentError) { Example.serialize([unsupported], type: Example.type) }
end

test "kind does not match another context's serializable type" do
	other = Literal::SerializationContext.new(Literal::StringSerializer, defaults: false)

	assert other.kind === other.type
	refute other.kind === Example.type
	refute Example.serializable_type?(other.type)
end

test "recursive kind support" do
	assert Example.kind === Example.type
	assert Example.kind === _TaggedUnion(foo: Example.type, bar: String)
	assert Example.kind === _Array(Example.type)
	assert Example.kind === _Set(Example.type)
	assert Example.kind === _Range(Example.type)
	assert Example.kind === SerializationRecursiveOrder
	assert Example.kind === SerializationRecursiveNode
end

test "recursive serializable types must loop through referenceable types" do
	recursive_array = nil
	recursive_array = _Deferred { _Array(recursive_array) }
	anonymous_node = Class.new(Literal::Data)

	anonymous_node.prop :child, anonymous_node

	assert Example.kind === recursive_array
	assert Example.kind === anonymous_node
	refute Example.kind === SerializationUnsupportedRecursiveNode

	assert_equal(
		Example.json_schema(recursive_array),
		{
			"type" => "array",
			"items" => { "$ref" => "#/$defs/0" },
			"$defs" => {
				"0" => {
					"type" => "array",
					"items" => { "$ref" => "#/$defs/0" },
				},
			},
		},
	)
	assert_equal(
		Example.json_schema(anonymous_node),
		{
			"type" => "object",
			"properties" => {
				"child" => { "$ref" => "#/$defs/0" },
			},
			"required" => ["child"],
			"additionalProperties" => false,
			"$defs" => {
				"0" => {
					"type" => "object",
					"properties" => {
						"child" => { "$ref" => "#/$defs/0" },
					},
					"required" => ["child"],
					"additionalProperties" => false,
				},
			},
		},
	)
	assert_raises(Literal::ArgumentError) { Example.json_schema(SerializationUnsupportedRecursiveNode) }
end

test "unserializable type errors explain the failure with a path" do
	error = assert_raises(Literal::ArgumentError) { Example.json_schema(SerializationUnsupportedRecursiveNode) }
	assert error.message.include?("there is no serializer for Object")
	assert error.message.include?("SerializationUnsupportedRecursiveNode → Object")

	error = assert_raises(Literal::ArgumentError) { Example.json_schema(_Union(String, Date)) }
	assert error.message.include?("String and Date both serialize to JSON string values")
	assert error.message.include?("use _TaggedUnion")
end

test "ambiguous union errors name the members that collide" do
	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(SerializationValueObject, SerializationLabel))
	end
	assert error.message.include?("SerializationValueObject")
	assert error.message.include?("SerializationLabel")
	assert error.message.include?("can match the same JSON objects")

	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(_Hash(String, String), SerializationValueObject))
	end
	assert error.message.include?("accepts arbitrary keys")

	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(Integer, Float))
	end
	assert error.message.include?("there is no serializer for Float")

	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(Integer, _Float(1..10)))
	end
	assert error.message.include?("both serialize to JSON number values")
	assert error.message.include?("_Float(finite?: true)")

	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(_Nilable(String), Integer))
	end
	assert error.message.include?("does not serialize to a single JSON type")

	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(String, Object))
	end
	assert error.message.include?("there is no serializer for Object")
end

test "ambiguous unions nested in structures explain the collision with a path" do
	nested = Class.new(Literal::Data)
	nested.prop :value, _Union(SerializationValueObject, SerializationLabel)

	error = assert_raises(Literal::ArgumentError) { Example.json_schema(nested) }
	assert error.message.include?("there is no serializer for _Union")
	assert error.message.include?("can match the same JSON objects")
	assert error.message.include?(" → ")
end

test "recursive set json schema" do
	type = nil
	type = _Set(_Deferred { type })

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "array",
			"uniqueItems" => true,
			"items" => { "$ref" => "#/$defs/0" },
			"$defs" => {
				"0" => {
					"type" => "array",
					"uniqueItems" => true,
					"items" => { "$ref" => "#/$defs/0" },
				},
			},
		},
	)
end

test "recursive tagged union members merge the discriminator into a fresh schema body" do
	tree = Class.new(Literal::Data)
	tree.prop :children, _Array(_TaggedUnion(tree:, leaf: String))

	assert Example.kind === tree

	original = tree.new(children: [tree.new(children: ["leaf"]), "another leaf"])
	serialized = Example.serialize(original, type: tree)

	assert_equal(serialized, {
		"children" => [
			{ "children" => [{ "$type" => "leaf", "value" => "leaf" }], "$type" => "tree" },
			{ "$type" => "leaf", "value" => "another leaf" },
		],
	})
	assert_equal(Example.deserialize(serialized, type: tree), original)

	assert_equal(
		Example.json_schema(tree),
		{
			"type" => "object",
			"properties" => {
				"children" => { "$ref" => "#/$defs/0" },
			},
			"required" => ["children"],
			"additionalProperties" => false,
			"$defs" => {
				"0" => {
					"type" => "array",
					"items" => {
						"oneOf" => [
							{
								"type" => "object",
								"properties" => {
									"children" => { "$ref" => "#/$defs/0" },
									"$type" => { "const" => "tree" },
								},
								"required" => ["$type", "children"],
								"additionalProperties" => false,
							},
							{
								"type" => "object",
								"properties" => {
									"$type" => { "const" => "leaf" },
									"value" => { "type" => "string" },
								},
								"required" => ["$type", "value"],
								"additionalProperties" => false,
							},
						],
					},
				},
			},
		},
	)
end

test "self-referential tagged unions are not serializable" do
	type = nil
	type = _TaggedUnion(a: _Deferred { type }, b: String)

	refute Example.kind === type
	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "mutually recursive container types" do
	inner = nil
	outer = _Array(_Array(_Deferred { outer })).tap { |it| inner = it.type }

	assert Example.kind === outer
	assert Example.kind === inner

	assert_equal(
		Example.json_schema(outer),
		{
			"type" => "array",
			"items" => {
				"type" => "array",
				"items" => { "$ref" => "#/$defs/0" },
			},
			"$defs" => {
				"0" => {
					"type" => "array",
					"items" => {
						"type" => "array",
						"items" => { "$ref" => "#/$defs/0" },
					},
				},
			},
		},
	)
end

test "shared types with a site-specific description keep the described copy inline" do
	pair = Class.new(Literal::Data)
	pair.prop :primary, SerializationPerson, description: "The main person"
	pair.prop :secondary, SerializationPerson

	person_schema = {
		"type" => "object",
		"properties" => {
			"name" => { "type" => "string" },
			"age" => { "type" => "integer" },
		},
		"required" => ["name", "age"],
		"additionalProperties" => false,
	}

	# The description is merged into a copy of the shared schema, so the
	# described occurrence stays inline while later occurrences reference a
	# definition. That definition can end up with a single reference.
	assert_equal(
		Example.json_schema(pair),
		{
			"type" => "object",
			"properties" => {
				"primary" => {
					**person_schema,
					"description" => "The main person",
				},
				"secondary" => { "$ref" => "#/$defs/0" },
			},
			"required" => ["primary", "secondary"],
			"additionalProperties" => false,
			"$defs" => {
				"0" => person_schema,
			},
		},
	)
end

test "later occurrences of a described shared type reference the definition with a description sibling" do
	pair = Class.new(Literal::Data)
	pair.prop :primary, SerializationPerson
	pair.prop :secondary, SerializationPerson, description: "The backup person"
	pair.prop :tertiary, SerializationPerson, description: "The other backup"

	schema = Example.json_schema(pair)

	assert_equal(schema.dig("properties", "primary"), { "$ref" => "#/$defs/0" })
	assert_equal(
		schema.dig("properties", "secondary"),
		{ "$ref" => "#/$defs/0", "description" => "The backup person" },
	)
	assert_equal(
		schema.dig("properties", "tertiary"),
		{ "$ref" => "#/$defs/0", "description" => "The other backup" },
	)
end

test "shared types are extracted into a single definition" do
	assert_equal(
		Example.json_schema(SerializationTeam),
		{
			"type" => "object",
			"properties" => {
				"lead" => { "$ref" => "#/$defs/0" },
				"backup" => { "$ref" => "#/$defs/0" },
			},
			"required" => ["lead", "backup"],
			"additionalProperties" => false,
			"$defs" => {
				"0" => {
					"type" => "object",
					"properties" => {
						"name" => { "type" => "string" },
						"age" => { "type" => "integer" },
					},
					"required" => ["name", "age"],
					"additionalProperties" => false,
				},
			},
		},
	)
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

test "integer and finite float union serializes as number" do
	type = _Union(Integer, _Float(finite?: true))

	assert_equal(Example.json_schema(type), { "type" => "number" })
	assert_equal(Example.json_schema(_Union(_Float(finite?: true), Integer)), { "type" => "number" })
	assert_equal(Example.serialize(1, type:), 1)
	assert_equal(Example.serialize(1.5, type:), 1.5)
	assert_equal(Example.deserialize(1, type:), 1)
	assert_equal(Example.deserialize(1.5, type:), 1.5)
end

test "integer and finite float union can be combined with other natural types" do
	type = _Union(String, Integer, _Float(finite?: true))

	assert_equal(
		Example.json_schema(type),
		{
			"oneOf" => [
				{ "type" => "string" },
				{ "type" => "number" },
			],
		},
	)

	assert_equal(Example.serialize("Joel", type:), "Joel")
	assert_equal(Example.serialize(1, type:), 1)
	assert_equal(Example.serialize(1.5, type:), 1.5)
	assert_equal(Example.deserialize("Joel", type:), "Joel")
	assert_equal(Example.deserialize(1, type:), 1)
	assert_equal(Example.deserialize(1.5, type:), 1.5)
end

test "range constrained integer and finite float union serializes as number" do
	type = _Constraint(1..20, 3..10, _Union(Integer, _Float(finite?: true)))

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "number",
			"minimum" => 3,
			"maximum" => 10,
		},
	)

	assert_equal(Example.serialize(3, type:), 3)
	assert_equal(Example.serialize(3.5, type:), 3.5)
	assert_equal(Example.deserialize(3, type:), 3)
	assert_equal(Example.deserialize(3.5, type:), 3.5)
end

test "exclusive range constrained integer and finite float union serializes as number" do
	type = _Constraint(1...10, _Union(Integer, _Float(finite?: true)))

	assert_equal(
		Example.json_schema(type),
		{
			"type" => "number",
			"minimum" => 1,
			"exclusiveMaximum" => 10,
		},
	)
end

test "integer and plain float union is not serializable" do
	type = _Union(Integer, Float)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "integer and constrained float union is not collapsed to number" do
	type = _Union(Integer, _Float(1..10))

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "same-kind union serialization roundtrip" do
	type = _Union(String, _String(length: 1..))
	original = "Joel"
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, "Joel")
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "natural union with an object member serialization roundtrip" do
	type = _Union(SerializationValueObject, String)
	object_original = SerializationValueObject.new(value: "Joel")
	string_original = "Joel"

	object_serialized = Example.serialize(object_original, type:)
	string_serialized = Example.serialize(string_original, type:)

	assert_equal(object_serialized, { "value" => "Joel" })
	assert_equal(string_serialized, "Joel")
	assert_equal(Example.deserialize(object_serialized, type:), object_original)
	assert_equal(Example.deserialize(string_serialized, type:), string_original)
end

test "natural union with a hash member serialization roundtrip" do
	type = _Union(_Hash(String, String), Integer)
	hash_original = { "name" => "Joel" }

	hash_serialized = Example.serialize(hash_original, type:)

	assert_equal(hash_serialized, { "name" => "Joel" })
	assert_equal(Example.deserialize(hash_serialized, type:), hash_original)
	assert_equal(Example.deserialize(Example.serialize(42, type:), type:), 42)
end

test "natural union with a map member serialization roundtrip" do
	type = _Union(_Map("$type": String, name: String), Integer)
	map_original = { "$type": "person", name: "Joel" }

	map_serialized = Example.serialize(map_original, type:)

	assert_equal(map_serialized, { "$type" => "person", "name" => "Joel" })
	assert_equal(Example.deserialize(map_serialized, type:), map_original)
end

test "natural union with an array member serialization roundtrip" do
	type = _Union(_Array(String), String)
	array_original = ["Joel", "Jill"]

	array_serialized = Example.serialize(array_original, type:)

	assert_equal(array_serialized, ["Joel", "Jill"])
	assert_equal(Example.deserialize(array_serialized, type:), array_original)
	assert_equal(Example.deserialize(Example.serialize("Joel", type:), type:), "Joel")
end

test "date and structure union serialization roundtrip" do
	type = _Union(Date, SerializationValueObject)
	date_original = Date.new(2025, 1, 13)
	object_original = SerializationValueObject.new(value: "Joel")

	date_serialized = Example.serialize(date_original, type:)
	object_serialized = Example.serialize(object_original, type:)

	assert_equal(date_serialized, "2025-01-13")
	assert_equal(object_serialized, { "value" => "Joel" })
	assert_equal(Example.deserialize(date_serialized, type:), date_original)
	assert_equal(Example.deserialize(object_serialized, type:), object_original)

	assert_equal(
		Example.json_schema(type),
		{
			"oneOf" => [
				{ "type" => "string", "format" => "date" },
				{
					"type" => "object",
					"properties" => {
						"value" => { "type" => "string" },
					},
					"required" => ["value"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "structures with positional properties roundtrip" do
	original = SerializationPoint.new(1, 2, label: "home")
	serialized = Example.serialize(original, type: SerializationPoint)

	assert_equal(serialized, { "x" => 1, "y" => 2, "label" => "home" })
	assert_equal(Example.deserialize(serialized, type: SerializationPoint), original)
end

test "omitted defaulted properties get their defaults when deserializing" do
	refute Example.json_schema(SerializationLeveled).fetch("required").include?("level")

	deserialized = Example.deserialize({ "name" => "Joel" }, type: SerializationLeveled)

	assert_equal(deserialized, SerializationLeveled.new(name: "Joel"))
	assert_equal(deserialized.level, 3)
end

test "never serializes to a schema that matches nothing" do
	assert Example.kind === _Never
	assert_equal(Example.json_schema(_Never), { "not" => {} })
end

test "never cannot serialize or deserialize values" do
	assert_raises(Literal::ArgumentError) { Example.serialize("Joel", type: _Never) }
	assert_raises(Literal::ArgumentError) { Example.deserialize("Joel", type: _Never) }
end

test "void discards serialized and deserialized values" do
	assert Example.kind === _Void
	assert_equal(Example.json_schema(_Void), true)
	assert_equal(Example.serialize(Object.new, type: _Void), nil)
	assert_equal(Example.deserialize(nil, type: _Void), nil)
	assert_equal(Example.deserialize("any JSON value", type: _Void), nil)
	assert_equal(Example.deserialize({ "nested" => [1, true] }, type: _Void), nil)
end

test "void does not have a single JSON type for union discrimination" do
	type = _Union(String, _Void)

	error = assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
	assert error.message.include?("_Void does not serialize to a single JSON type")
end

test "never union members are ignored" do
	type = _Union(String, SerializationValueObject, _Never)
	value_original = SerializationValueObject.new(value: "Joel")

	assert Example.kind === type
	assert_equal(Example.deserialize(Example.serialize("Joel", type:), type:), "Joel")
	assert_equal(Example.deserialize(Example.serialize(value_original, type:), type:), value_original)

	assert_equal(
		Example.json_schema(type),
		{
			"oneOf" => [
				{ "type" => "string" },
				{
					"type" => "object",
					"properties" => {
						"value" => { "type" => "string" },
					},
					"required" => ["value"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "arrays of never hold nothing but serialize" do
	type = _Array(_Never)

	assert_equal(Example.json_schema(type), { "type" => "array", "items" => { "not" => {} } })
	assert_equal(Example.serialize([], type:), [])
	assert_equal(Example.deserialize([], type:), [])
end

test "custom serializers can super to the serializer they shadow" do
	context = Literal::SerializationContext.new(SerializationRedactingSerializer)
	original = SerializationSecret.new(name: "Joel", secret: "hunter2")

	assert context.kind === SerializationSecret

	serialized = context.serialize(original, type: SerializationSecret)

	assert_equal(serialized, { "name" => "Joel", "secret" => "[redacted]" })

	deserialized = context.deserialize(serialized, type: SerializationSecret)

	assert_equal(deserialized, SerializationSecret.new(name: "Joel", secret: "[redacted]"))

	assert_equal(
		context.json_schema(SerializationSecret),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"secret" => { "type" => "string" },
			},
			"required" => ["name", "secret"],
			"additionalProperties" => false,
		},
	)
end

test "custom serializers super through each other in registration order" do
	context = Literal::SerializationContext.new(SerializationUpcasingSerializer, SerializationRedactingSerializer)
	original = SerializationSecret.new(name: "Joel", secret: "hunter2")

	serialized = context.serialize(original, type: SerializationSecret)

	assert_equal(serialized, { "name" => "JOEL", "secret" => "[redacted]" })
end

test "supering with no matching serializer later in the chain raises" do
	context = Literal::SerializationContext.new(SerializationOpaqueSerializer)

	error = assert_raises(Literal::ArgumentError) do
		context.serialize(SerializationOpaque.new, type: SerializationOpaque)
	end

	assert error.message.include?("No serializer for type")
	assert error.message.match?(/SerializationOpaque after .*SerializationOpaqueSerializer/)
end

test "codecs map values to an encoded type" do
	context = Literal::SerializationContext.new(SerializationMoneyCodec)
	original = SerializationMoney.new(100, "USD")

	assert context.kind === SerializationMoney

	serialized = context.serialize(original, type: SerializationMoney)

	assert_equal(serialized, { "cents" => 100, "currency" => "USD" })
	assert_equal(context.deserialize(serialized, type: SerializationMoney), original)

	assert_equal(
		context.json_schema(SerializationMoney),
		{
			"type" => "object",
			"properties" => {
				"cents" => { "type" => "integer" },
				"currency" => { "type" => "string" },
			},
			"required" => ["cents", "currency"],
			"additionalProperties" => false,
		},
	)
end

test "encoded types nest inside other serializable types" do
	context = Literal::SerializationContext.new(SerializationMoneyCodec)
	type = _Array(SerializationMoney)
	original = [SerializationMoney.new(100, "USD"), SerializationMoney.new(50, "GBP")]

	serialized = context.serialize(original, type:)

	assert_equal(serialized, [{ "cents" => 100, "currency" => "USD" }, { "cents" => 50, "currency" => "GBP" }])
	assert_equal(context.deserialize(serialized, type:), original)
end

test "codecs discriminate in unions through their encoded shape" do
	context = Literal::SerializationContext.new(SerializationMoneyCodec)
	type = _Union(SerializationMoney, String)
	money = SerializationMoney.new(100, "USD")

	money_serialized = context.serialize(money, type:)
	string_serialized = context.serialize("free", type:)

	assert_equal(money_serialized, { "cents" => 100, "currency" => "USD" })
	assert_equal(string_serialized, "free")
	assert_equal(context.deserialize(money_serialized, type:), money)
	assert_equal(context.deserialize(string_serialized, type:), "free")
end

test "codecs whose encoded type is a closed object merge tagged union discriminators" do
	context = Literal::SerializationContext.new(SerializationMoneyCodec)
	type = _TaggedUnion(money: SerializationMoney, note: String)
	original = SerializationMoney.new(100, "USD")

	serialized = context.serialize(original, type:)

	assert_equal(serialized, { "cents" => 100, "currency" => "USD", "$type" => "money" })
	assert_equal(context.deserialize(serialized, type:), original)
end

test "codecs delegate nested values to their serializers" do
	context = Literal::SerializationContext.new(SerializationSpanCodec)
	original = SerializationSpan.new((Date.new(2025, 1, 1))..(Date.new(2025, 12, 31)))

	assert context.kind === SerializationSpan

	serialized = context.serialize(original, type: SerializationSpan)

	assert_equal(serialized, { "from" => "2025-01-01", "to" => "2025-12-31", "inclusive" => true })
	assert_equal(context.deserialize(serialized, type: SerializationSpan), original)
end

test "codecs roundtrip exclusive and endless spans" do
	context = Literal::SerializationContext.new(SerializationSpanCodec)

	exclusive = SerializationSpan.new((Date.new(2025, 1, 1))...(Date.new(2025, 12, 31)))
	serialized = context.serialize(exclusive, type: SerializationSpan)

	assert_equal(serialized, { "from" => "2025-01-01", "to" => "2025-12-31", "inclusive" => false })
	assert_equal(context.deserialize(serialized, type: SerializationSpan), exclusive)

	endless = SerializationSpan.new((Date.new(2025, 1, 1))..)
	serialized = context.serialize(endless, type: SerializationSpan)

	assert_equal(serialized, { "from" => "2025-01-01", "to" => nil, "inclusive" => true })
	assert_equal(context.deserialize(serialized, type: SerializationSpan), endless)
end

test "codecs derive json schemas with nilable members from their encoded type" do
	context = Literal::SerializationContext.new(SerializationSpanCodec)

	assert_equal(
		context.json_schema(SerializationSpan),
		{
			"type" => "object",
			"properties" => {
				"from" => {
					"anyOf" => [
						{ "type" => "string", "format" => "date" },
						{ "type" => "null" },
					],
				},
				"to" => {
					"anyOf" => [
						{ "type" => "string", "format" => "date" },
						{ "type" => "null" },
					],
				},
				"inclusive" => { "type" => "boolean" },
			},
			"required" => ["inclusive"],
			"additionalProperties" => false,
		},
	)
end

test "codec encoded types may be handled by earlier serializers in the chain" do
	context = Literal::SerializationContext.new(SerializationMoneyCodec, SerializationWalletCodec)
	original = SerializationWallet.new(SerializationMoney.new(100, "USD"))

	assert context.serializable_type?(SerializationWallet)

	serialized = context.serialize(original, type: SerializationWallet)

	assert_equal(serialized, { "cents" => 100, "currency" => "USD" })
	assert_equal(context.deserialize(serialized, type: SerializationWallet), original)
end

test "codecs must implement type and encoded_type" do
	error = assert_raises(NoMethodError) do
		Literal::SerializationContext.new(Class.new(Literal::Serializer::Codec))
	end

	assert error.message.include?("must implement #type")

	codec = Class.new(Literal::Serializer::Codec) do
		def type = SerializationOpaque
	end

	context = Literal::SerializationContext.new(codec)

	error = assert_raises(NoMethodError) do
		context.serialize(SerializationOpaque.new, type: SerializationOpaque)
	end

	assert error.message.include?("must implement #encoded_type")
end

test "codecs must implement encode and decode" do
	codec = Class.new(Literal::Serializer::Codec) do
		def type = SerializationOpaque
		def encoded_type = _Map(value: String)
	end

	context = Literal::SerializationContext.new(codec)

	error = assert_raises(NoMethodError) do
		context.serialize(SerializationOpaque.new, type: SerializationOpaque)
	end

	assert error.message.include?("must implement #encode(value)")

	error = assert_raises(NoMethodError) do
		context.deserialize({ "value" => "example" }, type: SerializationOpaque)
	end

	assert error.message.include?("must implement #decode(value)")
end

test "codecs reject encoded types that are not serializable" do
	context = Literal::SerializationContext.new(SerializationBrokenCodec)

	refute context.kind === SerializationOpaque
	refute context.serializable_type?(SerializationOpaque)

	error = assert_raises(Literal::ArgumentError) { context.json_schema(SerializationOpaque) }

	assert error.message.include?("there is no serializer for Object")
	assert error.message.include?("SerializationOpaque → _Map({value: Object}) → Object")
end

test "coerced properties deserialize without re-running the coercion" do
	original = SerializationCoerced.new(date: "2025-01-13")

	assert_equal(original.date, Date.new(2025, 1, 13))

	serialized = Example.serialize(original, type: SerializationCoerced)

	assert_equal(serialized, { "date" => "2025-01-13" })
	assert_equal(Example.deserialize(serialized, type: SerializationCoerced), original)
end

test "union of object members with identical shapes is not naturally discriminated" do
	type = _Union(SerializationValueObject, SerializationLabel)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "union with two array members is not naturally discriminated" do
	type = _Union(_Array(String), _Set(Integer))

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "union of object members with distinct required keys serialization roundtrip" do
	type = _Union(SerializationValueObject, SerializationPerson)
	value_original = SerializationValueObject.new(value: "Joel")
	person_original = SerializationPerson.new(name: "Joel", age: 42)

	value_serialized = Example.serialize(value_original, type:)
	person_serialized = Example.serialize(person_original, type:)

	assert_equal(value_serialized, { "value" => "Joel" })
	assert_equal(person_serialized, { "name" => "Joel", "age" => 42 })
	assert_equal(Example.deserialize(value_serialized, type:), value_original)
	assert_equal(Example.deserialize(person_serialized, type:), person_original)

	assert_equal(
		Example.json_schema(type),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"value" => { "type" => "string" },
					},
					"required" => ["value"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"name" => { "type" => "string" },
						"age" => { "type" => "integer" },
					},
					"required" => ["name", "age"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "union of object members where one requires a key the other forbids" do
	type = _Union(SerializationNamed, SerializationPerson)
	named_original = SerializationNamed.new(name: "Joel")
	person_original = SerializationPerson.new(name: "Joel", age: 42)

	named_serialized = Example.serialize(named_original, type:)
	person_serialized = Example.serialize(person_original, type:)

	assert_equal(named_serialized, { "name" => "Joel" })
	assert_equal(person_serialized, { "name" => "Joel", "age" => 42 })
	assert_equal(Example.deserialize(named_serialized, type:), named_original)
	assert_equal(Example.deserialize(person_serialized, type:), person_original)
end

test "union of object members whose extra keys are all optional is not naturally discriminated" do
	type = _Union(SerializationTitled, SerializationDraft)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "union of a structure and a map with distinct required keys serialization roundtrip" do
	type = _Union(SerializationValueObject, _Map(name: String))
	value_original = SerializationValueObject.new(value: "Joel")
	map_original = { name: "Joel" }

	value_serialized = Example.serialize(value_original, type:)
	map_serialized = Example.serialize(map_original, type:)

	assert_equal(Example.deserialize(value_serialized, type:), value_original)
	assert_equal(Example.deserialize(map_serialized, type:), map_original)
end

test "union of a hash member and another object member is not naturally discriminated" do
	type = _Union(_Hash(String, String), SerializationValueObject)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "const discriminated structure union serialization roundtrip" do
	type = _Union(SerializationUserEvent, SerializationAdminEvent)
	user_original = SerializationUserEvent.new(kind: "user", name: "Joel")
	admin_original = SerializationAdminEvent.new(kind: "admin", name: "Jill")

	user_serialized = Example.serialize(user_original, type:)
	admin_serialized = Example.serialize(admin_original, type:)

	assert_equal(user_serialized, { "kind" => "user", "name" => "Joel" })
	assert_equal(admin_serialized, { "kind" => "admin", "name" => "Jill" })
	assert_equal(Example.deserialize(user_serialized, type:), user_original)
	assert_equal(Example.deserialize(admin_serialized, type:), admin_original)

	error = assert_raises(Literal::ArgumentError) do
		Example.deserialize({ "kind" => "other", "name" => "Joel" }, type:)
	end
	assert error.message.include?("No union member type for JSON object")
end

test "const discriminated map union serialization roundtrip" do
	type = _Union(
		_Map(kind: "circle", size: Integer),
		_Map(kind: "square", size: Integer),
	)

	circle_serialized = Example.serialize({ kind: "circle", size: 3 }, type:)
	square_serialized = Example.serialize({ kind: "square", size: 4 }, type:)

	assert_equal(circle_serialized, { "kind" => "circle", "size" => 3 })
	assert_equal(square_serialized, { "kind" => "square", "size" => 4 })
	assert_equal(Example.deserialize(circle_serialized, type:), { kind: "circle", size: 3 })
	assert_equal(Example.deserialize(square_serialized, type:), { kind: "square", size: 4 })

	assert_equal(
		Example.json_schema(type),
		{
			"oneOf" => [
				{
					"type" => "object",
					"properties" => {
						"kind" => { "type" => "string", "const" => "circle" },
						"size" => { "type" => "integer" },
					},
					"required" => ["kind", "size"],
					"additionalProperties" => false,
				},
				{
					"type" => "object",
					"properties" => {
						"kind" => { "type" => "string", "const" => "square" },
						"size" => { "type" => "integer" },
					},
					"required" => ["kind", "size"],
					"additionalProperties" => false,
				},
			],
		},
	)
end

test "symbol const discriminants roundtrip through their serialized form" do
	type = _Union(
		_Map(kind: :circle, size: Integer),
		_Map(kind: :square, size: Integer),
	)

	circle_serialized = Example.serialize({ kind: :circle, size: 3 }, type:)

	assert_equal(circle_serialized, { "kind" => "circle", "size" => 3 })
	assert_equal(Example.deserialize(circle_serialized, type:), { kind: :circle, size: 3 })
end

test "const discriminants that serialize identically do not discriminate" do
	type = _Union(
		_Map(kind: :user, name: String),
		_Map(kind: "user", name: String),
	)

	assert_raises(Literal::ArgumentError) { Example.json_schema(type) }
end

test "unions of consts as discriminant domains" do
	type = _Union(
		_Map(kind: _Union("circle", "ellipse"), size: Integer),
		_Map(kind: "square", size: Integer),
	)

	ellipse_serialized = Example.serialize({ kind: "ellipse", size: 3 }, type:)

	assert_equal(ellipse_serialized, { "kind" => "ellipse", "size" => 3 })
	assert_equal(Example.deserialize(ellipse_serialized, type:), { kind: "ellipse", size: 3 })

	overlapping = _Union(
		_Map(kind: _Union("circle", "ellipse"), size: Integer),
		_Map(kind: _Union("ellipse", "square"), size: Integer),
	)

	assert_raises(Literal::ArgumentError) { Example.json_schema(overlapping) }
end

test "integer const discriminants" do
	type = _Union(
		_Map(version: 1, payload: String),
		_Map(version: 2, payload: String),
	)

	v1_serialized = Example.serialize({ version: 1, payload: "a" }, type:)
	v2_serialized = Example.serialize({ version: 2, payload: "b" }, type:)

	assert_equal(Example.deserialize(v1_serialized, type:), { version: 1, payload: "a" })
	assert_equal(Example.deserialize(v2_serialized, type:), { version: 2, payload: "b" })
end

test "optional const keys do not discriminate object members" do
	type = _Union(
		_Map(kind: _Nilable("circle"), size: Integer),
		_Map(kind: _Nilable("square"), size: Integer),
	)

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

test "enum json schema uses the backing type schema with the enum values" do
	assert_equal(
		Example.json_schema(SerializationPriority),
		{ "type" => "integer", "enum" => [1, 2, 3] },
	)

	assert_equal(
		Example.json_schema(SerializationToggle),
		{ "type" => "boolean", "enum" => [true, false] },
	)
end

test "enum serialization roundtrip" do
	type = SerializationPriority
	serialized = Example.serialize(SerializationPriority::Medium, type:)

	assert_equal(serialized, 2)
	assert_equal(Example.deserialize(serialized, type:), SerializationPriority::Medium)
end

test "boolean-backed enum serialization roundtrip" do
	type = SerializationToggle
	serialized = Example.serialize(SerializationToggle::On, type:)

	assert_equal(serialized, true)
	assert_equal(Example.deserialize(serialized, type:), SerializationToggle::On)
end

test "symbol-backed enum serialization roundtrip" do
	type = SerializationSuit
	serialized = Example.serialize(SerializationSuit::Hearts, type:)

	assert_equal(serialized, "hearts")
	assert_equal(Example.deserialize(serialized, type:), SerializationSuit::Hearts)
end

test "symbol-backed enum json schema serializes the enum values" do
	# The enum values must be serialized through the backing type, so a
	# Symbol-backed enum should list JSON strings rather than raw symbols.
	assert_equal(
		Example.json_schema(SerializationSuit),
		{ "type" => "string", "enum" => ["hearts", "spades"] },
	)
end

test "enum deserialization coerces the raw backing value into a member" do
	assert_equal(Example.deserialize(3, type: SerializationPriority), SerializationPriority::High)
	assert_equal(Example.deserialize(false, type: SerializationToggle), SerializationToggle::Off)
end

test "enum property serialization roundtrip" do
	type = SerializationTask
	original = SerializationTask.new(name: "Ship", priority: SerializationPriority::High)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "name" => "Ship", "priority" => 3 })
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "enum property json schema" do
	assert_equal(
		Example.json_schema(SerializationTask),
		{
			"type" => "object",
			"properties" => {
				"name" => { "type" => "string" },
				"priority" => { "type" => "integer", "enum" => [1, 2, 3] },
			},
			"required" => ["name", "priority"],
			"additionalProperties" => false,
		},
	)
end

test "enum types are serializable" do
	assert Example.kind === SerializationPriority
	assert Example.kind === SerializationToggle
	assert Example.kind === SerializationSuit
end

test "union-backed enum serialization roundtrip" do
	type = SerializationCode

	slug_serialized = Example.serialize(SerializationCode::Slug, type:)
	number_serialized = Example.serialize(SerializationCode::Number, type:)

	assert_equal(slug_serialized, "welcome")
	assert_equal(number_serialized, 200)
	assert_equal(Example.deserialize(slug_serialized, type:), SerializationCode::Slug)
	assert_equal(Example.deserialize(number_serialized, type:), SerializationCode::Number)
end

test "union-backed enum is serializable when its backing union is" do
	assert Example.kind === SerializationCode
end

test "union-backed enum json schema intersects the backing schema with the enum values" do
	assert_equal(
		Example.json_schema(SerializationCode),
		{
			"oneOf" => [
				{ "type" => "string" },
				{ "type" => "integer" },
			],
			"enum" => ["welcome", 200],
		},
	)
end

test "an enum is not serializable when its backing type is not" do
	refute Example.kind === SerializationAmbiguousEnum

	error = assert_raises(Literal::ArgumentError) { Example.json_schema(SerializationAmbiguousEnum) }
	assert error.message.include?("SerializationAmbiguousEnum")
	assert error.message.include?("_Union(String, Date)")
end

test "a structure carrying an unserializable enum is not serializable" do
	holder = Class.new(Literal::Data)
	holder.prop :code, SerializationAmbiguousEnum

	refute Example.kind === holder
	assert_raises(Literal::ArgumentError) { Example.json_schema(holder) }
end

test "an enum member is serializable through the context's aggregate type" do
	assert Example.type === SerializationPriority::Medium

	serialized = Example.serialize(SerializationPriority::Medium, type: Example.type)

	assert_equal(serialized, 2)
end

test "enum in a union with a distinguishable type roundtrips" do
	type = _Union(SerializationPriority, String)

	member_serialized = Example.serialize(SerializationPriority::High, type:)
	string_serialized = Example.serialize("none", type:)

	assert_equal(member_serialized, 3)
	assert_equal(string_serialized, "none")
	assert_equal(Example.deserialize(member_serialized, type:), SerializationPriority::High)
	assert_equal(Example.deserialize(string_serialized, type:), "none")
end

test "enum in a union json schema nests the enum schema as a member" do
	assert_equal(
		Example.json_schema(_Union(SerializationPriority, String)),
		{
			"oneOf" => [
				{ "type" => "integer", "enum" => [1, 2, 3] },
				{ "type" => "string" },
			],
		},
	)
end

test "an enum that collides with a sibling union member is rejected" do
	error = assert_raises(Literal::ArgumentError) do
		Example.json_schema(_Union(SerializationSuit, String))
	end

	assert error.message.include?("SerializationSuit")
	assert error.message.include?("String")
end

test "serializing a value that is not a member of the enum raises" do
	assert_raises(Literal::ArgumentError) { Example.serialize("red", type: SerializationSuit) }
end

test "deserializing a value outside the enum raises" do
	assert_raises(ArgumentError) { Example.deserialize("green", type: SerializationSuit) }
end

class SerializationCollections < Literal::Data
	prop :tags, Literal::Array(String)
	prop :counts, Literal::Hash(Symbol, Integer)
	prop :pair, Literal::Tuple(String, Integer)
end

test "Literal::Array serialization roundtrip" do
	type = Literal::Array(String)
	original = type.new("a", "b")
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, ["a", "b"])
	assert_equal(serialized, Example.serialize(["a", "b"], type: _Array(String)))

	deserialized = Example.deserialize(serialized, type:)
	assert(Literal::Array === deserialized)
	assert_equal(deserialized, original)
end

test "Literal::Set serialization roundtrip" do
	type = Literal::Set(Symbol)
	original = type.new(:a, :b)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, ["a", "b"])

	deserialized = Example.deserialize(serialized, type:)
	assert(Literal::Set === deserialized)
	assert_equal(deserialized, original)
end

test "Literal::Hash serialization roundtrip" do
	type = Literal::Hash(Symbol, Integer)
	original = type.new({ a: 1, b: 2 })
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, { "a" => 1, "b" => 2 })
	assert_equal(serialized, Example.serialize({ a: 1, b: 2 }, type: _Hash(Symbol, Integer)))

	deserialized = Example.deserialize(serialized, type:)
	assert(Literal::Hash === deserialized)
	assert_equal(deserialized, original)
end

test "Literal::Tuple serialization roundtrip" do
	type = Literal::Tuple(String, Integer)
	original = type.new("a", 1)
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, ["a", 1])
	assert_equal(serialized, Example.serialize(["a", 1], type: _Tuple(String, Integer)))

	deserialized = Example.deserialize(serialized, type:)
	assert(Literal::Tuple === deserialized)
	assert_equal(deserialized, original)
end

test "collection instances serialize via the aggregate type" do
	assert_equal(Example.serialize(Literal::Array(String).new("a"), type: Example.type), ["a"])
	assert_equal(Example.serialize(Literal::Set(Symbol).new(:a), type: Example.type), ["a"])
	assert_equal(Example.serialize(Literal::Hash(Symbol, Integer).new({ a: 1 }), type: Example.type), { "a" => 1 })
	assert_equal(Example.serialize(Literal::Tuple(String, Integer).new("a", 1), type: Example.type), ["a", 1])
end

test "collection class json schema matches the equivalent type descriptor" do
	assert_equal(Example.json_schema(Literal::Array(String)), Example.json_schema(_Array(String)))
	assert_equal(Example.json_schema(Literal::Set(String)), Example.json_schema(_Set(String)))
	assert_equal(Example.json_schema(Literal::Hash(Symbol, Integer)), Example.json_schema(_Hash(Symbol, Integer)))
	assert_equal(Example.json_schema(Literal::Tuple(String, Integer)), Example.json_schema(_Tuple(String, Integer)))
end

test "nested collection classes serialize" do
	type = Literal::Array(Literal::Array(String))
	original = type.new(Literal::Array(String).new("a"))
	serialized = Example.serialize(original, type:)

	assert_equal(serialized, [["a"]])
	assert_equal(Example.deserialize(serialized, type:), original)
end

test "records with collection class props are serializable" do
	record = SerializationCollections.new(
		tags: Literal::Array(String).new("x", "y"),
		counts: Literal::Hash(Symbol, Integer).new({ a: 1 }),
		pair: Literal::Tuple(String, Integer).new("p", 2),
	)

	serialized = Example.serialize(record, type: SerializationCollections)
	assert_equal(serialized, { "tags" => ["x", "y"], "counts" => { "a" => 1 }, "pair" => ["p", 2] })

	deserialized = Example.deserialize(serialized, type: SerializationCollections)
	assert_equal(deserialized, record)
	assert(Literal::Array === deserialized.tags)

	assert_equal(
		Example.json_schema(SerializationCollections),
		{
			"type" => "object",
			"properties" => {
				"tags" => { "type" => "array", "items" => { "type" => "string" } },
				"counts" => {
					"type" => "object",
					"propertyNames" => { "type" => "string" },
					"additionalProperties" => { "type" => "integer" },
				},
				"pair" => {
					"type" => "array",
					"prefixItems" => [{ "type" => "string" }, { "type" => "integer" }],
					"minItems" => 2,
					"maxItems" => 2,
				},
			},
			"required" => ["tags", "counts", "pair"],
			"additionalProperties" => false,
		},
	)
end

test "a native array cannot be serialized as a Literal::Array collection type" do
	assert_raises(Literal::ArgumentError) do
		Example.serialize(["a"], type: Literal::Array(String))
	end
end
