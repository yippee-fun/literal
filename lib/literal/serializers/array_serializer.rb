# frozen_string_literal: true

class Literal::ArraySerializer < Literal::Serializer
	Tag = :array

	def initialize(context)
		@context = context
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
			@context.serialize(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		member_type = type.type

		raw.map do |item|
			@context.deserialize(item, type: member_type)
		end
	end
end
