# frozen_string_literal: true

# _Never has no values, so there is never anything to serialize or
# deserialize — but it can still appear in type signatures, so it needs a
# schema: one that matches nothing. This serializer must be registered ahead
# of the others: _Never is a subtype of every type, so any scalar serializer
# would otherwise claim it and publish a schema that accepts values the type
# rejects.
class Literal::NeverSerializer < Literal::Serializer
	def type
		Literal::Types::NeverType::Instance
	end

	def handles_type?(type)
		Literal::Types::NeverType === type
	end

	def json_schema(type, generator: nil)
		{ "not" => {} }
	end

	def serialize(value, type:)
		raise Literal::ArgumentError, "No value can be serialized as _Never"
	end

	def deserialize(raw, type:)
		raise Literal::ArgumentError, "No value can be deserialized as _Never"
	end
end
