# frozen_string_literal: true

class Literal::FloatSerializer < Literal::Serializer
	Type = _Float(finite?: true)

	def type
		Type
	end

	def json_type(type)
		"number"
	end

	def json_schema(type, generator: nil)
		case type
		when Float
			{ "type" => "number", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "number" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end

	def coerce(raw)
		case raw
		when Integer
			raw.to_f
		else
			raw
		end
	end

	private def union_json_schema(type, generator:)
		if type.types.empty?
			{ "type" => "number", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "number" }.tap do |schema|
			apply_range_constraints(schema, type.object_constraints.select { |constraint| Range === constraint })
		end
	end
end
