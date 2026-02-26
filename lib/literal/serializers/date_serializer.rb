# frozen_string_literal: true

class Literal::DateSerializer < Literal::Serializer
	Tag = :date
	Type = Date
	Kind = _Kind(Type)

	def tag
		Tag
	end

	def type
		Type
	end

	def kind
		Kind
	end

	def serialize(value, type:)
		value.strftime("%Y-%m-%d")
	end

	def deserialize(raw, type:)
		Date.parse(raw)
	end
end
