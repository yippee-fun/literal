# frozen_string_literal: true

class Literal::StringSerializer < Literal::Serializer
	Tag = :string
	Type = String
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
