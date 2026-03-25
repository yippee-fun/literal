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

		serialized_entries = value.map do |key, item|
			[
				serialize_contents(key, type: key_type),
				serialize_contents(item, type: value_type),
			]
		end

		if serialized_entries.all? { |key, _item| String === key }
			serialized_entries.to_h
		else
			serialized_entries
		end
	end

	def deserialize(raw, type:)
		key_type = type.key_type
		value_type = type.value_type

		raw.to_h do |key, item|
			[
				deserialize_contents(key, type: key_type),
				deserialize_contents(item, type: value_type),
			]
		end
	end
end
