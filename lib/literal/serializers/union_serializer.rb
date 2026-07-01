# frozen_string_literal: true

class Literal::Serializer::UnionType
	include Literal::Type

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableUnion"
	end

	def ===(value)
		@context.type === value
	end

	def >=(other, context: nil)
		return false unless Literal::Types::UnionType === other

		other.each.all? do |member|
			@context.tag_for_type(member)
			true
		rescue Literal::ArgumentError
			false
		end
	end
end

class Literal::UnionSerializer < Literal::Serializer
	Tag = :union

	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		if natural?(type)
			{
				"oneOf" => type.map { |member| json_schema_for(member) }.to_a,
			}
		else
			{
				"oneOf" => discriminated_members(type).map { |label, member| discriminated_json_schema(label, member) },
			}
		end
	end

	def serialize(value, type:)
		member_type = type.resolve(value)
		serialized = serialize_contents(value, type: member_type)

		if natural?(type)
			serialized
		elsif object_member?(member_type)
			{
				**serialized,
				"$type" => label_for_member(type, member_type),
			}
		else
			{
				"$type" => label_for_member(type, member_type),
				"value" => serialized,
			}
		end
	end

	def deserialize(raw_value, type:)
		if natural?(type)
			member_type = natural_member_type(raw_value, type)
			return deserialize_contents(raw_value, type: member_type)
		end

		tag_name = raw_value.fetch("$type")
		member_type = discriminated_members(type).assoc(tag_name)&.last

		unless member_type
			raise Literal::ArgumentError, "No union member type for tag #{tag_name.inspect} in #{type.inspect}"
		end

		if object_member?(member_type)
			deserialize_contents(raw_value.except("$type"), type: member_type)
		else
			deserialize_contents(raw_value.fetch("value"), type: member_type)
		end
	end

	SafeNaturalJSONTypes = Set["string", "integer", "number", "boolean", "null"].freeze

	private def natural?(type)
		seen = Set[]

		type.each.all? do |member|
			json_type = natural_json_type(member)
			return false unless json_type
			return false if seen.include?(json_type)
			return false if numeric_ambiguous?(seen, json_type)

			seen << json_type
		end
	end

	private def natural_json_type(type)
		schema = json_schema_for(type)
		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def numeric_ambiguous?(seen, json_type)
		(json_type == "integer" && seen.include?("number")) ||
			(json_type == "number" && seen.include?("integer"))
	end

	private def natural_member_type(raw_value, type)
		json_type = raw_json_type(raw_value)

		type.each.find { |member| natural_json_type(member) == json_type } ||
			natural_number_member_type(json_type, type) ||
			raise(Literal::ArgumentError, "No union member type for JSON type #{json_type.inspect} in #{type.inspect}")
	end

	private def natural_number_member_type(json_type, type)
		return unless json_type == "integer"

		type.each.find { |member| natural_json_type(member) == "number" }
	end

	private def raw_json_type(value)
		case value
		when String
			"string"
		when Integer
			"integer"
		when Float
			"number"
		when true, false
			"boolean"
		when nil
			"null"
		end
	end

	private def discriminated_members(type)
		members = type.to_a
		tags = members.map { |member| @context.tag_for_type(member).name }
		tag_counts = tags.tally

		members.each_with_index.map do |member, index|
			tag = tags[index]
			label = (tag_counts.fetch(tag) > 1) ? "#{tag}:#{index}" : tag

			[label, member]
		end
	end

	private def label_for_member(type, member_type)
		discriminated_members(type).find { |_label, member| member == member_type }&.first ||
			raise(Literal::ArgumentError, "No union member type #{member_type.inspect} in #{type.inspect}")
	end

	private def discriminated_json_schema(label, member)
		member_schema = json_schema_for(member)

		if mergeable_object_schema?(member_schema)
			return merge_discriminator_schema(label, member_schema)
		end

		{
			"type" => "object",
			"properties" => {
				"$type" => { "const" => label },
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

	private def merge_discriminator_schema(label, schema)
		schema.merge(
			"properties" => {
				**schema.fetch("properties", {}),
				"$type" => { "const" => label },
			},
			"required" => ["$type", *schema.fetch("required", [])],
		)
	end
end
