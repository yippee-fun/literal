# frozen_string_literal: true

class Literal::HashSerializer < Literal::Serializer
	Tag = :hash

	def initialize(context)
		@context = context
		@type = _Hash(@context.type, @context.type)
		@kind = _Kind(@type)
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

	def serialize(value, type:)
		key_type = type.key_type
		value_type = type.value_type

		value.to_h do |key, item|
			[
				@context.serialize(key, type: key_type),
				@context.serialize(item, type: value_type),
			]
		end
	end

	def deserialize(raw, type:)
		key_type = type.key_type
		value_type = type.value_type

		raw.to_h do |key, item|
			[
				@context.deserialize(key, type: key_type),
				@context.deserialize(item, type: value_type),
			]
		end
	end
end
