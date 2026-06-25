# frozen_string_literal: true

class Literal::FloatSerializer < Literal::Serializer
	Tag = :float
	Type = Float
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

	def coerce(raw)
		case raw
		when Integer
			raw.to_f
		else
			raw
		end
	end
end
