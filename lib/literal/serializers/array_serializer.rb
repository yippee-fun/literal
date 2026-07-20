# frozen_string_literal: true

class Literal::Serializer::ArrayType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableArray"
	end

	def ===(value)
		Array === value && value.all?(@context.type)
	end

	def matches?(other)
		case other
		when Literal::Types::ArrayType
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Types::ArrayType === constraint }
		else
			false
		end
	end
end

class Literal::ArraySerializer < Literal::Serializer
	def initialize(context)
		super
		@type = Literal::Serializer::ArrayType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		[array_type_for(type).type]
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"array"
	end

	def value_type(value)
		_Array(@context.type) if type === value
	end

	def json_schema(type, generator: nil)
		{ "type" => "array" }.tap do |schema|
			case type
			when Literal::Types::ArrayType
				schema["items"] = json_schema_for(type.type, generator:)
			when Literal::Types::ConstraintType
				array_type = array_type_for(type)
				schema["items"] = json_schema_for(array_type.type, generator:)

				apply_length_constraints(schema, type.property_constraints, min_key: "minItems", max_key: "maxItems")
			end
		end
	end

	def serialize(value, type:)
		member_type = array_type_for(type).type

		value.map do |item|
			serialize_contents(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		member_type = array_type_for(type).type

		raw.map do |item|
			deserialize_contents(item, type: member_type)
		end
	end

	private def array_type_for(type)
		case type
		when Literal::Types::ArrayType
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::ArrayType === constraint }
		end
	end
end
