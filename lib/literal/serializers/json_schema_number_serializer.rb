# frozen_string_literal: true

class Literal::JSONSchemaNumberSerializer < Literal::Serializer
	Type = Literal::JSONSchema::NumberType

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
