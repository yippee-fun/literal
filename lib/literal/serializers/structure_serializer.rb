# frozen_string_literal: true

class Literal::StructureSerializer < Literal::Serializer
	Tag = :structure

	def initialize(context)
		@context = context

		@type = _Predicate("SerializableStructure") do |object|
			Literal::DataStructure === object && object.class.literal_properties.all? { |property| @context.kind === property.type }
		end

		@kind = _Predicate("SerializableStructureKind") do |type|
			Class === type && type < Literal::DataStructure && type.literal_properties.all? { |property| @context.kind === property.type }
		end
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

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
