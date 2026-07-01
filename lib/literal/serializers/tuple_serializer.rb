# frozen_string_literal: true

class Literal::Serializer::TupleType
	include Literal::Type

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableTuple"
	end

	def ===(_value)
		false
	end

	def >=(other, context: nil)
		Literal::Types::TupleType === other && other.types.all? { |type| @context.kind === type }
	end
end

class Literal::TupleSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::TupleType.new(@context)
	end

	attr_reader :type

	def json_schema(type)
		{
			"type" => "array",
			"prefixItems" => type.types.map { |member_type| json_schema_for(member_type) },
			"minItems" => type.types.size,
			"maxItems" => type.types.size,
		}
	end

	def serialize(value, type:)
		type.types.each_with_index.map do |member_type, index|
			serialize_contents(value.fetch(index), type: member_type)
		end
	end

	def deserialize(raw, type:)
		type.types.each_with_index.map do |member_type, index|
			deserialize_contents(raw.fetch(index), type: member_type)
		end
	end
end
