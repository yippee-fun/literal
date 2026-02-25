# frozen_string_literal: true

class Literal::SetSerializer < Literal::Serializer
	Tag = :set

	def initialize(context)
		@context = context
		@type = _Set(@context.type)
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

		raw.to_set do |item|
			@context.deserialize(item, type: member_type)
		end
	end
end
