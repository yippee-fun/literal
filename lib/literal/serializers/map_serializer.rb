# frozen_string_literal: true

class Literal::Serializer::MapType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableMap"
	end

	def matches?(other)
		Literal::Types::MapType === other
	end
end

class Literal::MapSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::MapType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		type.shape.values
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"object"
	end

	def object_shape(type)
		required = Set[]
		allowed = Set[]
		const_domains = {}

		type.shape.each do |key, value_type|
			name = key.name
			allowed << name
			required << name unless value_type === nil

			if (domain = const_domain(value_type))
				const_domains[name] = domain
			end
		end

		Literal::Serializer::ObjectShape.new(required:, allowed:, const_domains:)
	end

	def json_schema(type, generator: nil)
		{
			"type" => "object",
			"properties" => type.shape.to_h do |key, value_type|
				[key.name, json_schema_for(value_type, generator:)]
			end,
			"required" => object_shape(type).required.to_a,
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
