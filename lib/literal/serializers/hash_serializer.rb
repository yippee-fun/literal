# frozen_string_literal: true

class Literal::Serializer::HashType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableHash"
	end

	def ===(value)
		Hash === value && value.all? do |key, item|
			@context.type === key && @context.type === item
		end
	end

	def matches?(other)
		case other
		when Literal::Types::HashType
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Types::HashType === constraint }
		else
			false
		end
	end
end

class Literal::HashSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::HashType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		hash_type = hash_type_for(type)
		[hash_type.key_type, hash_type.value_type]
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		string_keyed?(hash_type_for(type)) ? "object" : "array"
	end

	def value_type(value)
		_Hash(@context.type, @context.type) if type === value
	end

	def json_schema(type, generator: nil)
		hash_type = hash_type_for(type)
		key_schema = json_schema_for(hash_type.key_type, generator:)
		value_schema = json_schema_for(hash_type.value_type, generator:)

		schema = if string_keyed?(hash_type)
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

		if string_keyed?(hash_type)
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

	# Hashes serialize as JSON objects when their keys serialize as strings, and
	# as arrays of entry pairs otherwise. Recursive key types can never settle
	# on a string representation, so they use entries.
	private def string_keyed?(hash_type)
		return false if Literal::Types::DeferredType === hash_type.key_type

		json_type_for(hash_type.key_type) == "string"
	end

	private def apply_size_constraints(schema, type)
		return unless Literal::Types::ConstraintType === type

		if schema["type"] == "object"
			apply_length_constraints(schema, type.property_constraints, min_key: "minProperties", max_key: "maxProperties")
		else
			apply_length_constraints(schema, type.property_constraints, min_key: "minItems", max_key: "maxItems")
		end
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
