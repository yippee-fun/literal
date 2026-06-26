# frozen_string_literal: true

require "js_regex"

test "string json schema" do
	type = Literal::JSONSchema::String(format: "email", pattern: /\A[A-Z]+\z/, min_length: 7, max_length: 64)

	assert_equal(
		type.json_schema,
		{
			"type" => "string",
			"format" => "email",
			"pattern" => "/^[A-Z]+$/",
			"minLength" => 7,
			"maxLength" => 64,
		},
	)
end

test "string json schema validation" do
	email = Literal::JSONSchema::String(format: "email")
	uuid = Literal::JSONSchema::String(format: "uuid")
	pattern = Literal::JSONSchema::String(pattern: /\A[a-z]+\z/)

	assert email === "joel@example.com"
	refute email === "not-an-email"

	assert uuid === "2f9ec8cc-75d8-4711-81aa-b60a6d4506d5"
	refute uuid === "not-a-uuid"

	assert pattern === "literal"
	refute pattern === "Literal"
end

test "string json schema subtype" do
	assert_subtype Literal::JSONSchema::String, String
	assert_subtype Literal::JSONSchema::String(format: "email"), String
end

test "string json schema factory" do
	assert Literal::JSONSchema::StringType === Literal::JSONSchema::String
	assert Literal::JSONSchema::StringType === Literal::JSONSchema::String(format: "email")
end

test "integer json schema" do
	type = Literal::JSONSchema::Integer(minimum: 0, exclusive_minimum: nil, exclusive_maximum: 10, multiple_of: 2)

	assert_equal(
		type.json_schema,
		{
			"type" => "integer",
			"minimum" => 0,
			"exclusiveMaximum" => 10,
			"multipleOf" => 2,
		},
	)

	assert type === 8
	refute type === 9
	refute type === 10
	refute type === 1.5
end

test "integer json schema subtype" do
	assert_subtype Literal::JSONSchema::Integer, Integer
	assert_subtype Literal::JSONSchema::Integer(minimum: 0), Numeric
end

test "integer json schema factory" do
	assert Literal::JSONSchema::IntegerType === Literal::JSONSchema::Integer
	assert Literal::JSONSchema::IntegerType === Literal::JSONSchema::Integer(minimum: 0)
end

test "number json schema" do
	type = Literal::JSONSchema::Number(exclusive_minimum: 0, maximum: 1.5)

	assert_equal(
		type.json_schema,
		{
			"type" => "number",
			"exclusiveMinimum" => 0,
			"maximum" => 1.5,
		},
	)

	assert type === 1
	assert type === 1.5
	refute type === 0
	refute type === Float::INFINITY
end

test "number json schema subtype" do
	assert_subtype Literal::JSONSchema::Number, Float
	assert_subtype Literal::JSONSchema::Number(maximum: 1.5), Numeric
end

test "number json schema factory" do
	assert Literal::JSONSchema::NumberType === Literal::JSONSchema::Number
	assert Literal::JSONSchema::NumberType === Literal::JSONSchema::Number(maximum: 1.5)
end
