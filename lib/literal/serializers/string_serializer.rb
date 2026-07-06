# frozen_string_literal: true

class Literal::StringSerializer < Literal::Serializer
	Type = String

	def type
		Type
	end

	def json_type(type)
		"string"
	end

	def json_schema(type, generator: nil)
		case type
		when Literal::JSONSchema::StringType
			type.json_schema
		when String
			{ "type" => "string", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end

	private def union_json_schema(type, generator:)
		if type.types.empty?
			{ "type" => "string", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Regexp
					if defined? JsRegex
						schema["pattern"] = JsRegex.new(constraint, target: "ES2018").source
					end
				end
			end

			apply_length_constraints(schema, type.property_constraints, min_key: "minLength", max_key: "maxLength")
		end
	end
end
