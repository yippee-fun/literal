# frozen_string_literal: true

class Literal::JSONSchemaNumberSerializer < Literal::Serializer
	Tag = :json_schema_number
	Type = Literal::JSONSchema::NumberType

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		type.json_schema
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end

	def coerce(raw)
		case raw
		when Integer
			raw.to_f
		else
			raw
		end
	end
end
