# frozen_string_literal: true

class Literal::Serializer::StructureType
	include Literal::Type

	def initialize(kind)
		@kind = kind
		freeze
	end

	def inspect
		"SerializableStructure"
	end

	def ===(object)
		Literal::DataStructure === object && object.class.literal_properties.all? { |property| @kind === property.type }
	end

	def >=(other, context: nil)
		Class === other && other < Literal::DataStructure && other.literal_properties.all? { |property| @kind === property.type }
	end
end

class Literal::StructureSerializer < Literal::Serializer
	Tag = :structure

	def initialize(context)
		@context = context

		@type = Literal::Serializer::StructureType.new(@context.kind)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		properties = type.literal_properties.to_h do |property|
			[property.name.to_s, json_schema_for(property.type)]
		end

		{
			"type" => "object",
			"properties" => properties,
			"required" => type.literal_properties.filter(&:required?).map { |property| property.name.to_s },
			"additionalProperties" => false,
		}
	end

	def serialize(value, type:)
		type.literal_properties.to_h do |property|
			[
				property.name.to_s,
				serialize_contents(value.__send__(property.name), type: property.type),
			]
		end
	end

	def deserialize(raw, type:)
		type.new(
			**type.literal_properties.to_h do |property|
				[
					property.name,
					deserialize_contents(raw[property.name.to_s], type: property.type),
				]
			end
		)
	end
end
