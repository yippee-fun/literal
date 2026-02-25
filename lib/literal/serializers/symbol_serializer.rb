# frozen_string_literal: true

class Literal::SymbolSerializer < Literal::Serializer
	Tag = :symbol
	Type = Symbol
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
		value.name
	end

	def deserialize(raw, type:)
		raw.to_sym
	end
end
