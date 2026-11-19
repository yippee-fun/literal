# frozen_string_literal: true

# A serializer for one of the Literal collection classes (Literal::Array,
# Literal::Set, Literal::Hash, Literal::Tuple). Like Literal::Serializer::Codec,
# it delegates to a serializable type the context already knows how to handle —
# here the collection's primitive type (`type.primitive_type`, e.g.
# Literal::Array(String) -> _Array(String)) and its primitive serializer.
#
# Unlike a codec, the wire type is parameterized by the dispatched type rather
# than fixed, so the full Literal::Serializer protocol is used and dispatch is a
# shallow structural match through the companion Kind. Subclasses provide:
#
#   generic_class    — the collection's Generic (e.g. Literal::Array::Generic)
#   reconstruct(value) — rebuild the precise Generic from a collection instance
#
# The dispatched type is either the Generic itself or a Literal::Types::ConstraintType
# wrapping it; both are mapped to their primitive form before delegating.
class Literal::Serializer::CollectionSerializer < Literal::Serializer
	def generic_class
		raise NoMethodError.new("#{self.class} must implement #generic_class, returning the collection's Generic class.")
	end

	def reconstruct(value)
		raise NoMethodError.new("#{self.class} must implement #reconstruct(value), rebuilding the Generic from an instance.")
	end

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		primitive_serializer(type).child_types(primitive_type(type))
	end

	def referenceable?(type)
		primitive_serializer(type).referenceable?(primitive_type(type))
	end

	def json_type(type)
		primitive_serializer(type).json_type(primitive_type(type))
	end

	def object_shape(type)
		primitive_serializer(type).object_shape(primitive_type(type))
	end

	def json_schema(type, generator: nil)
		primitive_serializer(type).json_schema(primitive_type(type), generator:)
	end

	def serialize(value, type:)
		primitive_serializer(type).serialize(value.__value__, type: primitive_type(type))
	end

	def deserialize(raw, type:)
		serializer = primitive_serializer(type)
		primitive = primitive_type(type)

		generic_for(type).coerce(
			serializer.deserialize(serializer.coerce(raw), type: primitive),
		)
	end

	# Aggregate-type inference: rebuild the precise Generic for a collection
	# instance so the strict check and primitive_type get the exact member types
	# (the Kind's === only answers whether the value is serializable, not which
	# type it is).
	def value_type(value)
		reconstruct(value) if @type === value
	end

	# The primitive type values map to on the wire. For a bare Generic this is
	# its own primitive_type; for a ConstraintType wrapping the Generic, the
	# Generic is mapped to its primitive while every other constraint (bare
	# modules, property constraints) is left untouched.
	private def primitive_type(type)
		case type
		when generic_class
			type.primitive_type
		when Literal::Types::ConstraintType
			Literal::Types::ConstraintType.new(
				type.object_constraints.map { |constraint| (generic_class === constraint) ? constraint.primitive_type : constraint },
				type.property_constraints,
			)
		end
	end

	# The Generic to coerce a deserialized value back into — the type itself, or
	# the one wrapped inside a ConstraintType. A ConstraintType has no #coerce,
	# which is why deserialize must reach for the Generic here.
	private def generic_for(type)
		case type
		when generic_class
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| generic_class === constraint }
		end
	end

	# The serializer the context would pick for the primitive type. It can never
	# be this serializer — primitive_type maps the Generic away, so the primitive
	# is matched only by the primitive serializer — but we guard defensively, as
	# Codec does, to keep the no-recursion invariant explicit.
	private def primitive_serializer(type)
		primitive = primitive_type(type)
		serializer = @context.serializer_for_type(primitive)
		serializer.equal?(self) ? super_serializer(primitive) : serializer
	end
end
