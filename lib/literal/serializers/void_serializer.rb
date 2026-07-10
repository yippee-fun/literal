# frozen_string_literal: true

# _Void deliberately discards its value. Its serializer kind must not match
# values itself, otherwise adding _Void to a context would make the context's
# inferred serializable type match every Ruby object.
class Literal::Serializer::VoidType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableVoid"
	end

	def ===(_value)
		false
	end

	def matches?(other)
		Literal::Types::VoidType === other
	end
end

class Literal::VoidSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::VoidType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def json_schema(type, generator: nil)
		true
	end

	def serialize(value, type:)
		nil
	end

	def deserialize(raw, type:)
		nil
	end
end
