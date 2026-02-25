# frozen_string_literal: true

class Literal::BooleanSerializer < Literal::Serializer
	Tag = :boolean
	Type = _Boolean
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
		value
	end

	def deserialize(raw, type:)
		raw
	end
end
