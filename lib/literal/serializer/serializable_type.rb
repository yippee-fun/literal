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

	# Serializer kinds refer back to this type through the context, so like
	# `_Deferred` it is where a match can cycle, and re-entry answers false.
	def ===(value)
		Literal.with_match_guard(self, value) { @type === value }
	end

	def literal_supertype_of?(other, context:)
		@context.serializable_type?(other)
	end
end
