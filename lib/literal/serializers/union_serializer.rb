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

		natural?(other)
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
		schema = @context.json_schema(type)
		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def numeric_ambiguous?(seen, json_type)
		(json_type == "integer" && seen.include?("number")) ||
			(json_type == "number" && seen.include?("integer"))
	end
end

class Literal::UnionSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	attr_reader :type

	def json_schema(type)
		{
			"oneOf" => type.map { |member| json_schema_for(member) }.to_a,
		}
	end

	def serialize(value, type:)
		member_type = type.resolve(value)
		serialize_contents(value, type: member_type)
	end

	def deserialize(raw_value, type:)
		member_type = natural_member_type(raw_value, type)
		deserialize_contents(raw_value, type: member_type)
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
end
