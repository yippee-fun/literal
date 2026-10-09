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

	# JSON data is passed through, but its objects are sorted by key at every
	# depth, like every other serialized object. Arrays keep their order.
	def serialize(value, type:)
		sort_keys(value)
	end

	def deserialize(raw, type:)
		raw
	end

	private def sort_keys(value)
		case value
		when Hash
			value.sort_by { |key, _| key }.to_h { |key, item| [key, sort_keys(item)] }
		when Array
			value.map { |item| sort_keys(item) }
		else
			value
		end
	end
end
