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

	# If we can coerce a float to an integer without losing anything, we’ll accept it.
	def coerce(value)
		case value
		when Float
			coerced = value.to_i
			(coerced == value) ? coerced : value
		else
			value
		end
	end
end
