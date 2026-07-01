# frozen_string_literal: true

class Literal::Serializer::NilableType
	include Literal::Type

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableNilable"
	end

	def ===(value)
		nil === value
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::NilableType
			Literal.subtype?(other.type, @context.type, context:)
		when nil
			true
		else
			false
		end
	end
end

class Literal::NilableSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::NilableType.new(@context)
	end

	attr_reader :type

	def json_schema(type)
		return { "type" => "null" } if type.nil?
		return { "type" => "null" } if Literal::Serializer::NilableType === type

		{
			"anyOf" => [
				json_schema_for(type.type),
				{ "type" => "null" },
			],
		}
	end

	def serialize(value, type:)
		case value
		when nil
			nil
		else
			serialize_contents(value, type: type.type)
		end
	end

	def deserialize(raw, type:)
		case raw
		when nil
			nil
		else
			deserialize_contents(raw, type: type.type)
		end
	end
end
