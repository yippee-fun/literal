# frozen_string_literal: true

require "js_regex"
require "json_schemer"

include Literal::Types

class ValidationPerson < Literal::Data
	prop :name, String
	prop :age, Integer
end

class ValidationProfile < Literal::Data
	prop :owner, ValidationPerson
	prop :friends, _Array(ValidationPerson)
	prop? :bio, _String(length: 1..200)
end

class ValidationNode < Literal::Data
	prop :name, String
	prop :children, _Array(_Deferred { ValidationNode })
end

ValidationContext = Literal::SerializationContext.new

# For every case, the serialized value must round-trip through
# deserialization and validate against the generated JSON Schema — the schema
# must perfectly describe what serialization produces.
test "serialized values validate against their generated JSON Schemas" do
	recursive_hash = nil
	recursive_hash = _Hash(String, _Nilable(_Deferred { recursive_hash }))

	cases = [
		[String, "hello"],
		["exact", "exact"],
		[Symbol, :symbol],
		[_Union(:draft, :published), :draft],
		[Integer, 42],
		[_Integer(1...10), 9],
		[_Float(finite?: true), 3.14],
		[_Boolean, false],
		[true, true],
		[Date, Date.new(2025, 1, 13)],
		[_String(length: 2..5, size: 3..), "abcd"],
		[_String(/\A[a-z]+\z/), "abc"],
		[_Array(String), ["a", "b"]],
		[_Constraint(_Array(Integer), length: 1..3), [1, 2]],
		[_Set(Symbol), Set[:a, :b]],
		[_Tuple(String, Integer, _Boolean), ["a", 1, true]],
		[_Hash(Symbol, Integer), { a: 1, b: 2 }],
		[_Hash(String, _Nilable(String)), { "a" => nil, "b" => "c" }],
		[_Hash(Integer, String), { 1 => "a", 2 => "b" }],
		[_Map(name: String, age: Integer, nickname: _Nilable(String)), { name: "Joel", age: 42, nickname: nil }],
		[_Nilable(String), nil],
		[_Nilable(String), "present"],
		[_Union(String, Integer), "either"],
		[_Union(String, Integer), 42],
		[_Union(Integer, _Float(finite?: true)), 1],
		[_Union(Integer, _Float(finite?: true)), 1.5],
		[_Constraint(1..20, _Union(Integer, _Float(finite?: true))), 7.5],
		[_TaggedUnion(person: ValidationPerson, note: String), ValidationPerson.new(name: "Jill", age: 40)],
		[_TaggedUnion(person: ValidationPerson, note: String), "a note"],
		[_TaggedUnion(hash: _Hash(Symbol, Integer), array: _Array(String)), { count: 3 }],
		[_JSONData, { "nested" => [1, "two", nil, true, { "deep" => [] }] }],
		[ValidationPerson, ValidationPerson.new(name: "Joel", age: 42)],
		[
			ValidationProfile,
			ValidationProfile.new(
				owner: ValidationPerson.new(name: "Joel", age: 42),
				friends: [ValidationPerson.new(name: "Jill", age: 40), ValidationPerson.new(name: "Jack", age: 41)],
			),
		],
		[
			ValidationNode,
			ValidationNode.new(name: "root", children: [
				ValidationNode.new(name: "branch", children: [
					ValidationNode.new(name: "leaf", children: []),
				]),
				ValidationNode.new(name: "leaf", children: []),
			]),
		],
		[recursive_hash, { "a" => { "b" => nil }, "c" => nil }],
	]

	cases.each do |type, value|
		schema = ValidationContext.json_schema(type)
		serialized = ValidationContext.serialize(value, type:)

		schemer = JSONSchemer.schema(schema)
		errors = schemer.validate(serialized).map { |error| error.fetch("error") }

		assert_equal(errors, []) # the schema must accept exactly what serialization produced
		assert_equal(ValidationContext.deserialize(serialized, type:), value)
	end
end
