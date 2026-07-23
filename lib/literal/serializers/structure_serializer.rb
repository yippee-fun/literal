# frozen_string_literal: true

class Literal::Serializer::StructureType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableStructure"
	end

	# Values only match if their whole structure type is serializable, so that
	# matching context.type agrees with what serialization will accept.
	def ===(object)
		Literal::DataStructure === object && @context.serializable_type?(object.class)
	end

	def matches?(other)
		Class === other && other < Literal::DataStructure
	end
end

class Literal::StructureSerializer < Literal::Serializer
	def initialize(context)
		@context = context

		@type = Literal::Serializer::StructureType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		type.literal_properties.map { |property| without_undefined(property.type) }
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"object"
	end

	def value_type(value)
		value.class if type === value
	end

	def object_shape(type)
		required = Set[]
		allowed = Set[]
		const_domains = {}

		type.literal_properties.each do |property|
			name = property.name.name
			allowed << name
			required << name if property.required? && !undefined_optional?(property.type)

			if (domain = const_domain(without_undefined(property.type)))
				const_domains[name] = domain
			end
		end

		Literal::Serializer::ObjectShape.new(required:, allowed:, const_domains:)
	end

	def json_schema(type, generator: nil)
		properties = type.literal_properties.to_h do |property|
			[property.name.name, property_json_schema(property, generator:)]
		end

		{
			"type" => "object",
			"properties" => properties,
			"required" => object_shape(type).required.to_a,
			"additionalProperties" => false,
		}
	end

	def mergeable_object?(type)
		Class === type && type < Literal::DataStructure
	end

	def serialize(value, type:)
		type.literal_properties.filter_map do |property|
			property_value = value.__send__(property.name)
			next if property_value == Literal::Undefined

			[
				property.name.name,
				serialize_contents(property_value, type: without_undefined(property.type)),
			]
		end.to_h
	end

	def deserialize(raw, type:)
		type.from_props(
			type.literal_properties.filter_map do |property|
				if raw.key?(property.name.name)
					[
						property.name,
						deserialize_contents(raw[property.name.name], type: without_undefined(property.type)),
					]
				elsif undefined_optional?(property.type)
					# An undefined property is omitted when serialized, so a missing
					# key deserializes back to Literal::Undefined — not the property's
					# default, which is what an omitted from_props key would resolve to.
					[property.name, Literal::Undefined]
				end
			end.to_h
		)
	end

	private def property_json_schema(property, generator:)
		schema = json_schema_for(without_undefined(property.type), generator:)
		return schema unless property.description?

		# Merge rather than mutate: the child schema may be shared through a
		# "$defs" entry, and the description belongs to this property site only.
		schema = {} unless Hash === schema
		schema.merge("description" => property.description)
	end
end
