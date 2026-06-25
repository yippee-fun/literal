# frozen_string_literal: true

class Literal::Serializer
	extend Literal::Types
	include Literal::Types

	def initialize(context)
		@context = context
	end

	def serialize_contents(value, type:)
		@context.serialize(value, type:, strict: false)
	end

	def deserialize_contents(value, type:)
		@context.deserialize(value, type:, strict: false)
	end

	# This gives you an opportunity to coerce raw values before type checking and deserialization.
	def coerce(raw)
		raw
	end
end
