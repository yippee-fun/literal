# frozen_string_literal: true

class Literal::Serializer::TaggedUnionType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableTaggedUnion"
	end

	def ===(value)
		@context.type === value
	end

	def matches?(other)
		Literal::Types::TaggedUnionType === other
	end
end

class Literal::TaggedUnionSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::TaggedUnionType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		type.members.values
	end

	def value_type(value)
	end

	def json_schema(type, generator: nil)
		{
			"oneOf" => type.members.map do |tag, member_type|
				tagged_json_schema(tag.name, member_type, generator:)
			end,
		}
	end

	def serialize(value, type:)
		tag, member_type = type.resolve(value)
		serialized = serialize_contents(value, type: member_type)

		if object_member?(member_type)
			return {
				**serialized,
				"$type" => tag.name,
			}
		end

		{
			"$type" => tag.name,
			"value" => serialized,
		}
	end

	def deserialize(raw, type:)
		tag = raw.fetch("$type")
		member_type = type[tag.to_sym]

		if object_member?(member_type)
			deserialize_contents(raw.except("$type"), type: member_type)
		else
			deserialize_contents(raw.fetch("value"), type: member_type)
		end
	end

	private def tagged_json_schema(tag, member_type, generator:)
		if object_member?(member_type)
			# Serialization merges the discriminator into the member object, so the
			# schema must too. Since a discriminator cannot be merged into a
			# "$ref", we ask for a fresh schema body (reference: false), which
			# works even for members that recurse back into this tagged union.
			member_schema = json_schema_for(member_type, generator:, reference: false)

			unless mergeable_object_schema?(member_schema)
				raise Literal::ArgumentError, "Cannot generate a JSON Schema for tagged union member #{member_type.inspect} because its schema cannot be merged with the $type discriminator."
			end

			return merge_discriminator_schema(tag, member_schema)
		end

		{
			"type" => "object",
			"properties" => {
				"$type" => { "const" => tag },
				"value" => json_schema_for(member_type, generator:),
			},
			"required" => ["$type", "value"],
			"additionalProperties" => false,
		}
	end

	private def mergeable_object_schema?(schema)
		Hash === schema &&
			schema["type"] == "object" &&
			schema.fetch("additionalProperties", nil) == false &&
			!schema.fetch("properties", {}).key?("$type")
	end

	private def object_member?(member_type)
		@context.serializer_for_type(member_type).mergeable_object?(member_type)
	rescue Literal::ArgumentError
		false
	end

	private def merge_discriminator_schema(tag, schema)
		schema.merge(
			"properties" => {
				**schema.fetch("properties", {}),
				"$type" => { "const" => tag },
			},
			"required" => ["$type", *schema.fetch("required", [])],
		)
	end
end
