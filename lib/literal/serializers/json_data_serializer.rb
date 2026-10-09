# frozen_string_literal: true

class Literal::JSONDataSerializer < Literal::Serializer
	Type = _JSONData

	def type
		Type
	end

	# No const dispatch: _JSONData === x is true for any JSON-shaped value, so
	# the default fallback would let this catch-all swallow const types other
	# serializers deliberately reject with diagnostic errors — mixed-numeric
	# unions like _Union(1, 1.0), or collection literals used as types.
	def handles_type?(type)
		Literal.subtype?(type, self.type)
	end

	def json_schema(type, generator: nil)
		true
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end
end
