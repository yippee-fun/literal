# frozen_string_literal: true

class Literal::IntegerSerializer < Literal::Serializer
	Tag = :integer
	Type = Integer
	Kind = _Kind(Integer)

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

	def deserialize(value, type:)
		value
	end
end
