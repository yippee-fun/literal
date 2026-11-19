# frozen_string_literal: true

class Literal::Rails::EnumType < ActiveModel::Type::Value
	def initialize(enum, subtype = ActiveModel::Type.default_value)
		@enum = enum
		@subtype = subtype
		super()
	end

	attr_reader :subtype

	def type
		:literal_enum
	end

	def cast(value)
		case value
		in nil
			nil
		in ^@enum | Symbol
			@enum.coerce(value)
		else
			@enum.coerce(@subtype.cast(value))
		end
	end

	def serialize(value)
		case value
		in ^@enum | Symbol
			@subtype.serialize(@enum.coerce(value).value)
		else
			@subtype.serialize(value)
		end
	end

	def deserialize(value)
		case @subtype.deserialize(value)
		in nil
			nil
		in raw
			@enum.coerce(raw)
		end
	end
end
