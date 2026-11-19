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
		in ^@enum | Symbol
			@enum.coerce(value)
		else
			member_for(@subtype.cast(value))
		end
	end

	def serialize(value)
		@subtype.serialize(database_value(value))
	end

	def serializable?(value, &)
		@subtype.serializable?(database_value(value), &)
	end

	def deserialize(value)
		member_for(@subtype.deserialize(value))
	end

	# Form and database strings name the member whose backing value reads the same.
	private def member_for(raw)
		case raw
		in nil
			nil
		in String
			@enum[raw] || @enum.find { |it| it.value.to_s == raw } || (@enum.coerce(raw) unless raw.blank?)
		else
			@enum.coerce(raw)
		end
	end

	private def database_value(value)
		case value
		in ^@enum | Symbol | String
			cast(value)&.value
		else
			value
		end
	end
end
