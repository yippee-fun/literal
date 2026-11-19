# frozen_string_literal: true

class Literal::BooleanSerializer < Literal::Serializer
	Type = _Boolean

	def type
		Type
	end

	def json_type(type)
		"boolean"
	end

	def json_schema(type, generator: nil)
		case type
		when true, false
			{ "type" => "boolean", "const" => type }
		else
			{ "type" => "boolean" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end
end
