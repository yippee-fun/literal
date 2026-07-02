# frozen_string_literal: true

class Literal::IntegerSerializer < Literal::Serializer
	Type = Integer

	def type
		Type
	end

	def json_type(type)
		"integer"
	end

	def json_schema(type, generator: nil)
		case type
		when Literal::JSONSchema::IntegerType
			type.json_schema
		when Integer
			{ "type" => "integer", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "integer" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(value, type:)
		value
	end

	# If we can coerce a float to an integer without losing anything, we’ll accept it.
	def coerce(value)
		case value
		when Float
			coerced = value.to_i
			(coerced == value) ? coerced : value
		else
			value
		end
	end

	private def union_json_schema(type, generator:)
		if type.types.empty?
			{ "type" => "integer", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "integer" }.tap do |schema|
			apply_range_constraints(schema, type.object_constraints.select { |constraint| Range === constraint })
		end
	end
end
