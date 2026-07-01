# frozen_string_literal: true

class Literal::HashSerializer < Literal::Serializer
	Tag = :hash

	def initialize(context)
		@context = context
		@type = _Hash(@context.type, @context.type)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		hash_type = hash_type_for(type)
		key_schema = json_schema_for(hash_type.key_type)
		value_schema = json_schema_for(hash_type.value_type)

		schema = if string_key_schema?(key_schema)
			{
				"type" => "object",
				"propertyNames" => key_schema,
				"additionalProperties" => value_schema,
			}
		else
			{
				"type" => "array",
				"items" => {
					"type" => "array",
					"prefixItems" => [key_schema, value_schema],
					"minItems" => 2,
					"maxItems" => 2,
				},
			}
		end

		apply_size_constraints(schema, type)
		schema
	end

	def serialize(value, type:)
		hash_type = hash_type_for(type)
		key_type = hash_type.key_type
		value_type = hash_type.value_type

		serialized_entries = value.map do |key, item|
			[
				serialize_contents(key, type: key_type),
				serialize_contents(item, type: value_type),
			]
		end

		if serialized_entries.all? { |key, _item| String === key }
			serialized_entries.to_h
		else
			serialized_entries
		end
	end

	def deserialize(raw, type:)
		hash_type = hash_type_for(type)
		key_type = hash_type.key_type
		value_type = hash_type.value_type

		raw.to_h do |key, item|
			[
				deserialize_contents(key, type: key_type),
				deserialize_contents(item, type: value_type),
			]
		end
	end

	private def string_key_schema?(schema)
		schema["type"] == "string" || (schema["anyOf"] && schema["anyOf"].all? { |item| string_key_schema?(item) })
	end

	private def apply_size_constraints(schema, type)
		return unless Literal::Types::ConstraintType === type

		type.property_constraints.each do |property, constraint|
			case [property, constraint]
			in [:length | :size, Range]
				apply_max_size_constraint(schema, range_end(constraint)) if constraint.end
				apply_min_size_constraint(schema, constraint.begin) if constraint.begin
			in [:length | :size, Integer]
				apply_max_size_constraint(schema, constraint)
				apply_min_size_constraint(schema, constraint)
			end
		end
	end

	private def apply_max_size_constraint(schema, value)
		schema[object_schema?(schema) ? "maxProperties" : "maxItems"] = value
	end

	private def apply_min_size_constraint(schema, value)
		schema[object_schema?(schema) ? "minProperties" : "minItems"] = value
	end

	private def object_schema?(schema)
		schema["type"] == "object"
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end

	private def hash_type_for(type)
		case type
		when Literal::Types::HashType
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::HashType === constraint }
		end
	end
end
