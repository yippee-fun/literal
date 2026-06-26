# frozen_string_literal: true

class Literal::BooleanSerializer < Literal::Serializer
	Tag = :boolean
	Type = _Boolean

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		{ "type" => "boolean" }
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end
end
