# frozen_string_literal: true

class Literal::NilableSerializer < Literal::Serializer
	Tag = :nilable

	def initialize(context)
		@context = context
		@type = _Nilable(@context.type)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		return { "type" => "null" } if type.nil?

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
