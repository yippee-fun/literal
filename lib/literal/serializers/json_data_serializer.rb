# frozen_string_literal: true

class Literal::JSONDataSerializer < Literal::Serializer
	Type = _JSONData

	def type
		Type
	end

	def json_schema(type, generator: nil)
		true
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end
end
