# frozen_string_literal: true

class Literal::Serializer
	extend Literal::Types
	include Literal::Types

	def initialize(context)
		@context = context
	end

	# Shallow dispatch check: is this node structurally one of ours? This must
	# not recurse into child types — the context's serializability walk owns all
	# recursion. Serializers with structured kinds override this with a purely
	# structural match; the default covers scalar serializers whose type is a
	# plain Literal type.
	def handles_type?(type)
		Literal.subtype?(type, self.type)
	end

	# The child types this serializer would recurse into when serializing a
	# value of the given type. These must be exactly the types serialize,
	# deserialize and json_schema recurse into, so that the serializability walk
	# agrees with what actually happens.
	def child_types(type)
		[]
	end

	# Whether a node of this type may be the target of a JSON Schema "$ref" —
	# which is also what makes recursion through it legal.
	def referenceable?(type)
		false
	end

	# The top-level JSON type ("string", "integer", …) of the schema this
	# serializer emits for the given type, or nil when there isn't a single one.
	def json_type(type)
		nil
	end

	# The key shape of the closed JSON object schema this serializer emits for
	# the given type, or nil when its schema is not a closed object — open
	# hashes included, since an unbounded key set proves nothing.
	def object_shape(type)
		nil
	end

	# A sentence explaining why this serializer refuses the given type, or nil
	# when it handles the type or has nothing specific to say. Only consulted
	# on the error path, to enrich unserializable type messages.
	def rejection_reason(type)
		nil
	end

	def serialize_contents(value, type:)
		@context.serialize(value, type:, strict: false)
	end

	def deserialize_contents(value, type:)
		@context.deserialize(value, type:, strict: false)
	end

	def json_schema_for(type, generator:, reference: true)
		generator.schema(type, reference:)
	end

	# The serializer that would handle the type if this one were not
	# registered: the next matching serializer in the context's chain. This
	# lets a custom serializer transform a value and delegate the remaining
	# work, like calling super. Any protocol method can be forwarded to it —
	# child_types, referenceable? and object_shape included, which delegating
	# serializers should usually forward so the serializability walk and union
	# discrimination see through them.
	def super_serializer(type)
		@context.serializer_for_type(type, after: self)
	end

	def super_serialize(value, type:)
		super_serializer(type).serialize(value, type:)
	end

	# Applies the next serializer's raw value coercion before deserializing,
	# just as the context would if that serializer had handled the type.
	def super_deserialize(raw, type:)
		serializer = super_serializer(type)
		serializer.deserialize(serializer.coerce(raw), type:)
	end

	def super_json_schema(type, generator: nil)
		super_serializer(type).json_schema(type, generator:)
	end

	def value_type(value)
		type if type === value
	end

	def mergeable_object?(type)
		false
	end

	# This gives you an opportunity to coerce raw values before type checking and deserialization.
	def coerce(raw)
		raw
	end

	private def json_type_for(type)
		@context.json_type(type)
	end

	# Whether the type is a union permitting Literal::Undefined, marking a
	# property or shape key that is omitted when serializing an undefined value
	# and restored to Literal::Undefined when its key is missing.
	private def undefined_optional?(type)
		Literal::Types::UnionType === type && type.types.include?(Literal::Undefined)
	end

	# The type an undefined-optional value serializes as when it is present.
	# Literal::Undefined is never serialized as a standalone value — it only
	# exists as the absence of a key — so it is stripped before recursing.
	private def without_undefined(type)
		return type unless undefined_optional?(type)

		type.reject { |member_type| member_type == Literal::Undefined }
	end

	# The finite set of raw JSON values the given type can serialize to, or nil
	# when the domain is unbounded or unknown. Constants have singleton domains;
	# a union of constants has the union of theirs. Domains are compared as
	# serialized values, so a Symbol and a String constant that write the same
	# JSON share a domain.
	private def const_domain(type)
		case type
		when Literal::Types::UnionType
			domains = type.each.map { |member| const_domain(member) }
			domains.reduce(Set[], :|) if domains.all?
		when String, Symbol, Integer, Float, true, false
			Set[@context.serialize(type, type:)]
		end
	end

	private def apply_length_constraints(schema, property_constraints, min_key:, max_key:)
		property_constraints.each do |property, constraint|
			case [property, constraint]
			in [:length | :size, Range]
				schema[max_key] = range_end(constraint) if constraint.end
				schema[min_key] = constraint.begin if constraint.begin
			in [:length | :size, Integer]
				schema[max_key] = constraint
				schema[min_key] = constraint
			else
				# Constraints JSON Schema cannot express are ignored. The schema is
				# looser than the type, but still accepts everything serialization
				# produces, since serialized values are checked against the type.
			end
		end
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end

	private def apply_range_constraints(schema, ranges)
		minimum, maximum, exclusive_maximum = narrowed_range_bounds(ranges)

		schema["minimum"] = minimum unless minimum.nil?

		unless maximum.nil?
			if exclusive_maximum
				schema["exclusiveMaximum"] = maximum
			else
				schema["maximum"] = maximum
			end
		end
	end

	private def narrowed_range_bounds(ranges)
		minimum = nil
		maximum = nil
		exclusive_maximum = false

		ranges.each do |range|
			minimum = range.begin if !range.begin.nil? && (minimum.nil? || range.begin > minimum)

			next if range.end.nil?

			if maximum.nil? || range.end < maximum
				maximum = range.end
				exclusive_maximum = range.exclude_end?
			elsif range.end == maximum && range.exclude_end?
				exclusive_maximum = true
			end
		end

		[minimum, maximum, exclusive_maximum]
	end
end
