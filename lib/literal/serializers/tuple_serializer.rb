# frozen_string_literal: true

class Literal::Serializer::TupleType
	include Literal::Serializer::Kind

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

	def matches?(other)
		Literal::Types::TupleType === other || Literal::Tuple::Generic === other
	end
end

class Literal::TupleSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::TupleType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		type.types
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"array"
	end

	def value_type(value)
		Literal.Tuple(*value.__types__) if Literal::Tuple === value
	end

	def json_schema(type, generator: nil)
		{
			"type" => "array",
			"prefixItems" => type.types.map { |member_type| json_schema_for(member_type, generator:) },
			"minItems" => type.types.size,
			"maxItems" => type.types.size,
		}
	end

	def serialize(value, type:)
		source = (Literal::Tuple === value) ? value.__value__ : value

		type.types.each_with_index.map do |member_type, index|
			serialize_contents(source.fetch(index), type: member_type)
		end
	end

	def deserialize(raw, type:)
		result = type.types.each_with_index.map do |member_type, index|
			deserialize_contents(raw.fetch(index), type: member_type)
		end

		(Literal::Tuple::Generic === type) ? type.coerce(result) : result
	end
end
