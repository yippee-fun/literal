# frozen_string_literal: true

require "set"

class Literal::Serializer::StructureType
	include Literal::Type

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableStructure"
	end

	def ===(object)
		Literal::DataStructure === object && serializable_structure_type?(object.class)
	end

	def >=(other, context: nil)
		Class === other && other < Literal::DataStructure && serializable_structure_type?(other)
	end

	private def serializable_structure_type?(type)
		@context.serializable_type?(type) && with_structure_guard(type) do
			type.literal_properties.all? do |property|
				property_type = property_schema_type(property.type)

				serializable_property_type?(property_type) ||
					recursive_property_type?(property_type, type)
			end
		end
	end

	private def serializable_property_type?(type)
		Literal.subtype?(type, @context.type)
	end

	private def recursive_property_type?(type, root, stack: Set[])
		type = type.materialize if type in Literal::Types::DeferredType

		return dereferenceable_structure_type?(type) if type.equal?(root)
		return true if serializable_property_type?(type)
		return false unless type.respond_to?(:literal_child_types)

		key = type.object_id
		return false if stack.include?(key)

		stack.add(key)

		type.literal_child_types.all? do |child_type|
			recursive_property_type?(child_type, root, stack:)
		end
	ensure
		stack.delete(key) if key
	end

	private def dereferenceable_structure_type?(type)
		Class === type && type < Literal::DataStructure && type.name
	end

	private def property_schema_type(type)
		return type unless undefined_optional?(type)

		type.reject { |member_type| member_type == Literal::Undefined }
	end

	private def undefined_optional?(type)
		Literal::Types::UnionType === type && type.types.include?(Literal::Undefined)
	end

	private def with_structure_guard(type)
		state = (Thread.current[:literal_serializable_structure_state] ||= {})
		key = [object_id, type.object_id]

		return true if state[key]

		added = true
		state[key] = true
		yield
	ensure
		state&.delete(key) if added
		Thread.current[:literal_serializable_structure_state] = nil if state&.empty?
	end
end

class Literal::StructureSerializer < Literal::Serializer
	def initialize(context)
		@context = context

		@type = Literal::Serializer::StructureType.new(@context)
	end

	attr_reader :type

	def value_type(value)
		value.class if type === value
	end

	def json_schema(type, generator: nil)
		properties = type.literal_properties.to_h do |property|
			[property.name.to_s, property_json_schema(property, generator:)]
		end

		{
			"type" => "object",
			"properties" => properties,
			"required" => type.literal_properties.filter(&:required?).map { |property| property.name.to_s },
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

	private def property_json_schema(property, generator:)
		json_schema_for(property_schema_type(property.type), generator:).tap do |schema|
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
