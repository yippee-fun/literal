# frozen_string_literal: true

# Basic primitive type tests
test "string type mapping" do
	assert_schema String, {
		type: "string",
	}
end

test "integer type mapping" do
	assert_schema Integer, {
		type: "integer",
	}
end

test "float type mapping" do
	assert_schema Float, {
		type: "number",
	}
end

test "boolean type mapping" do
	assert_schema Literal::Types::_Boolean, {
		type: "boolean",
	}
end

# Range type tests
test "integer range mapping" do
	assert_schema 1..10, {
		type: "integer",
		minimum: 1,
		maximum: 10,
	}
end

test "exclusive integer range mapping" do
	assert_schema 1...10, {
		type: "integer",
		minimum: 1,
		maximum: 10,
		exclusiveMaximum: true,
	}
end

test "float range mapping" do
	assert_schema 1.0..10.0, {
		type: "number",
		minimum: 1.0,
		maximum: 10.0,
	}
end

# Array type tests
test "string array mapping" do
	assert_schema Literal::Array(String), {
		type: "array",
		items: {
			type: "string",
		},
	}
end

test "integer array mapping" do
	assert_schema Literal::Array(Integer), {
		type: "array",
		items: {
			type: "integer",
		},
	}
end

# Enum type tests
test "enum type mapping" do
	class Colors < Literal::Enum(String)
		Red = new("Red")
		Blue = new("Blue")
		Green = new("Green")
	end

	assert_schema Colors, {
		type: "string",
		enum: ["Red", "Blue", "Green"],
	}
end

# Data structure tests
test "basic data structure mapping" do
	class Person < Literal::Data
		prop :name, String
		prop :age, Integer
		prop :email, _String?
	end

	expected_schema = {
		type: "object",
		properties: {
			name: { type: "string" },
			age: { type: "integer" },
			email: { type: "string", nullable: true },
		},
		required: ["name", "age"],
		additionalProperties: false,
	}

	assert_equal Literal::JsonSchema::Generator.generate(Person), expected_schema
end

test "nested data structure mapping" do
	class Address < Literal::Data
		prop :street, String
		prop :city, String
		prop :country, String
	end

	class Contact < Literal::Data
		prop :name, String
		prop :address, Address
		prop :phone_numbers, Literal::Array(String)
	end

	expected_schema = {
		type: "object",
		properties: {
			name: { type: "string" },
			address: {
				type: "object",
				properties: {
					street: { type: "string" },
					city: { type: "string" },
					country: { type: "string" },
				},
				required: ["street", "city", "country"],
				additionalProperties: false,
			},
			phone_numbers: {
				type: "array",
				items: { type: "string" },
			},
		},
		required: ["name", "address", "phone_numbers"],
		additionalProperties: false,
	}

	assert_equal expected_schema, Literal::JsonSchema::Generator.generate(Contact)
end

test "openapi compatibility with date-time format" do
	class ApiResponse < Literal::Data
		prop :id, Integer
		prop :status, String
		prop :created_at, Time
		prop :created_at_const, _Time?
		prop :date_added, Date
		prop :date_added_const, _Date?
	end

	expected_schema = {
		type: "object",
		properties: {
			id: { type: "integer" },
			status: { type: "string" },
			created_at: {
				type: "string",
				format: "date-time",
			},

			created_at_const: {
				type: "string",
				format: "date-time",
				nullable: true,
			},

			date_added: {
				type: "string",
				format: "date",
			},

			date_added_const: {
				type: "string",
				format: "date",
				nullable: true,
			},
		},
		required: ["id", "status", "created_at", "date_added"],
		additionalProperties: false,
	}

	assert_equal expected_schema, Literal::JsonSchema::Generator.generate(ApiResponse)
end

private

def assert_schema(type, expected)
	actual = Literal::JsonSchema::TypeMapper.map_type(type)
	assert_equal actual, expected
end
