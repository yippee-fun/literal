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
		Literal::DataStructure === object && object.class.literal_properties.all? { |property| serializable_property_type?(property.type) }
	end

	def >=(other, context: nil)
		Class === other && other < Literal::DataStructure && other.literal_properties.all? { |property| serializable_property_type?(property.type) }
	end

	private def serializable_property_type?(type)
		@kind === property_schema_type(type)
	end

	private def property_schema_type(type)
		return type unless undefined_optional?(type)

		type.reject { |member_type| member_type == Literal::Undefined }
	end

	private def undefined_optional?(type)
		Literal::Types::UnionType === type && type.types.include?(Literal::Undefined)
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
			[property.name.to_s, property_json_schema(property)]
		end

		{
			"type" => "object",
			"properties" => properties,
			"required" => type.literal_properties.filter(&:required?).map { |property| property.name.to_s },
			"additionalProperties" => false,
		}
	end

	def serialize(value, type:)
		type.literal_properties.filter_map do |property|
			property_value = value.__send__(property.name)
			next if property_value == Literal::Undefined

			[
				property.name.to_s,
				serialize_contents(property_value, type: property_schema_type(property.type)),
			]
		end.to_h
	end

	def deserialize(raw, type:)
		type.new(
			**type.literal_properties.filter_map do |property|
				next if undefined_optional?(property.type) && !raw.key?(property.name.to_s)

				[
					property.name,
					deserialize_contents(raw[property.name.to_s], type: property_schema_type(property.type)),
				]
			end.to_h
		)
	end

	private def property_json_schema(property)
		json_schema_for(property_schema_type(property.type)).tap do |schema|
			schema["description"] = property.description if property.description?
		end
	end

	private def undefined_optional?(type)
		Literal::Types::UnionType === type && type.types.include?(Literal::Undefined)
	end

	private def property_schema_type(type)
		return type unless undefined_optional?(type)

		type.reject { |member_type| member_type == Literal::Undefined }
	end
end
