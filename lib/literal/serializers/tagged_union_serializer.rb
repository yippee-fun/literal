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
				{
					"type" => "object",
					"properties" => {
						"type" => { "type" => "string", "const" => tag.name },
						"value" => json_schema_for(member_type),
					},
					"required" => ["type", "value"],
					"additionalProperties" => false,
				}
			end,
		}
	end

	def serialize(value, type:)
		tag, member_type = type.resolve(value)

		{
			"type" => tag.name,
			"value" => serialize_contents(value, type: member_type),
		}
	end

	def deserialize(raw, type:)
		tag = raw.fetch("type")
		value = raw.fetch("value")
		member_type = type[tag.to_sym]

		deserialize_contents(value, type: member_type)
	end
end
