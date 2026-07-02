# frozen_string_literal: true

class Literal::SymbolSerializer < Literal::Serializer
	Type = Symbol

	def type
		Type
	end

	def json_type(type)
		"string"
	end

	def json_schema(type, generator: nil)
		case type
		when Symbol
			{ "type" => "string", "const" => type.name }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string" }
		end
	end

	def serialize(value, type:)
		value.name
	end

	def deserialize(raw, type:)
		raw.to_sym
	end

	private def union_json_schema(type, generator:)
		if type.types.empty?
			{ "type" => "string", "enum" => type.primitives.map(&:name) }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string" }.tap do |schema|
			apply_length_constraints(schema, type.property_constraints, min_key: "minLength", max_key: "maxLength")
		end
	end
end
