# frozen_string_literal: true

# A serializer defined as a two-way mapping between a class and an encoded
# type the context already knows how to serialize. Subclasses implement four
# methods:
#
#   type          — the class this serializer handles
#   encoded_type  — the serializable type values map to on the wire
#   encode(value) — map a value into the encoded type
#   decode(value) — map an encoded value back
#
# encode and decode are shallow: anything nested inside the encoded value is
# handled by the encoded type's own serializer through normal dispatch, so a
# codec never serializes its children. Everything else — JSON Schema
# generation, the serializability walk, union discrimination — derives from
# the encoded type, and is guaranteed to agree with what serialization
# actually does.
#
# None of the four methods receives the dispatched type: encoded_type takes
# no argument so a codec always maps to a single wire shape, and encode and
# decode work on values alone, since dispatch may hand a codec any subtype of
# its type — including a union of subtypes — so there is no single class
# there to rely on. Serializers for parameterized generics need the full
# Literal::Serializer protocol, where dispatch is a shallow structural match
# rather than a subtype check.
class Literal::Serializer::Codec < Literal::Serializer
	def type
		raise NoMethodError.new("#{self.class} must implement #type, returning the class it serializes.")
	end

	def encoded_type
		raise NoMethodError.new("#{self.class} must implement #encoded_type, returning the serializable type values map to.")
	end

	def encode(value)
		raise NoMethodError.new("#{self.class} must implement #encode(value), mapping a value into its encoded type.")
	end

	def decode(value)
		raise NoMethodError.new("#{self.class} must implement #decode(value), mapping an encoded value back.")
	end

	def child_types(type)
		[encoded]
	end

	def referenceable?(type)
		encoded_serializer.referenceable?(encoded)
	end

	def json_type(type)
		encoded_serializer.json_type(encoded)
	end

	def object_shape(type)
		encoded_serializer.object_shape(encoded)
	end

	def mergeable_object?(type)
		encoded_serializer.mergeable_object?(encoded)
	end

	def json_schema(type, generator: nil)
		encoded_serializer.json_schema(encoded, generator:)
	end

	def serialize(value, type:)
		encoded_serializer.serialize(
			encode(value),
			type: encoded,
		)
	end

	def deserialize(raw, type:)
		serializer = encoded_serializer

		decode(
			serializer.deserialize(serializer.coerce(raw), type: encoded),
		)
	end

	private def encoded
		@encoded ||= encoded_type
	end

	# The serializer the context would pick for the encoded type. Only when
	# that would be this codec itself does dispatch resume after it, so a
	# codec whose encoded type still matches it cannot recurse into itself.
	private def encoded_serializer
		@encoded_serializer ||= begin
			serializer = @context.serializer_for_type(encoded)
			serializer.equal?(self) ? super_serializer(encoded) : serializer
		end
	end
end
