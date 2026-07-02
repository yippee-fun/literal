# frozen_string_literal: true

class Literal::Serializer::MapType
	include Literal::Type
	include Literal::Serializer::RecursiveType

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableMap"
	end

	def >=(other, context: nil)
		Literal::Types::MapType === other && serializable_map_type?(other)
	end

	private def serializable_map_type?(type)
		serializable_children?(type, type.shape.values)
	end
end

class Literal::MapSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::MapType.new(@context)
	end

	attr_reader :type

	def json_schema(type, generator: nil)
		{
			"type" => "object",
			"properties" => type.shape.to_h do |key, value_type|
				[key.name, json_schema_for(value_type, generator:)]
			end,
			"required" => type.shape.reject { |_key, value_type| value_type === nil }.keys.map(&:name),
			"additionalProperties" => false,
		}
	end

	def mergeable_object?(type)
		Literal::Types::MapType === type && !type.shape.key?(:$type)
	end

	def serialize(value, type:)
		type.shape.to_h do |key, value_type|
			[key.name, serialize_contents(value[key], type: value_type)]
		end
	end

	def deserialize(raw, type:)
		type.shape.to_h do |key, value_type|
			[key, deserialize_contents(raw[key.name], type: value_type)]
		end
	end
end
