# frozen_string_literal: true

# The aggregate type of everything a serialization context can serialize. As a
# value type it matches any serializable value; as a supertype it accepts any
# type the context can fully serialize, including recursive types.
class Literal::Serializer::SerializableType
	include Literal::Type

	def initialize(context, type)
		@context = context
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		@type.inspect
	end

	def ===(value)
		@type === value
	end

	def >=(other, context: nil)
		@context.serializable_type?(other)
	end
end
