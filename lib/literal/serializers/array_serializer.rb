# frozen_string_literal: true

class Literal::ArraySerializer < Literal::Serializer
	Tag = :array

	def initialize(context)
		super
		@type = _Array(@context.type)
		@kind = _Kind(@type)
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

	def serialize(value, type:)
		member_type = type.type

		value.map do |item|
			serialize_contents(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		member_type = type.type

		raw.map do |item|
			deserialize_contents(item, type: member_type)
		end
	end
end
