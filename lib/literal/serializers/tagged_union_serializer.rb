# frozen_string_literal: true

class Literal::Serializer::TaggedUnionType
	include Literal::Type
	include Literal::Types

	def initialize(context)
		@context = context
		@type = _Union(@context.type)
		freeze
	end

	def inspect
		"SerializableTaggedUnion"
	end

	def ===(value)
		@type === value
	end

	def >=(other, context: nil)
		Literal::Types::TaggedUnionType === other && other.members.each_value.all? { |member_type| Literal.subtype?(member_type, @context.type, context:) }
	end
end

class Literal::TaggedUnionSerializer < Literal::Serializer
	Tag = :tagged_union

	def initialize(context)
		@context = context
		@type = Literal::Serializer::TaggedUnionType.new(@context)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		{
			"oneOf" => type.members.map do |tag, member_type|
				tagged_json_schema(tag.name, member_type)
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
			deserialize_contents(raw.reject { |key, _| key == "$type" }, type: member_type)
		else
			deserialize_contents(raw.fetch("value"), type: member_type)
		end
	end

	private def tagged_json_schema(tag, member_type)
		member_schema = json_schema_for(member_type)

		if mergeable_object_schema?(member_schema)
			return merge_discriminator_schema(tag, member_schema)
		end

		{
			"type" => "object",
			"properties" => {
				"$type" => { "const" => tag },
				"value" => member_schema,
			},
			"required" => ["$type", "value"],
			"additionalProperties" => false,
		}
	end

	private def mergeable_object_schema?(schema)
		schema["type"] == "object" &&
			schema.fetch("additionalProperties", nil) == false &&
			!schema.fetch("properties", {}).key?("$type")
	end

	private def object_member?(member_type)
		serializer = @context.serializer_for_type(member_type)

		case serializer.tag
		when :structure
			return false unless Class === member_type && member_type < Literal::DataStructure
		when :map
			return false unless Literal::Types::MapType === member_type
		else
			return false
		end

		mergeable_object_schema?(json_schema_for(member_type))
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
