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

	def serialize_contents(value, type:)
		@context.serialize(value, type:, strict: false)
	end

	def deserialize_contents(value, type:)
		@context.deserialize(value, type:, strict: false)
	end

	def json_schema_for(type, generator:, reference: true)
		generator.schema(type, reference:)
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

	private def apply_length_constraints(schema, property_constraints, min_key:, max_key:)
		property_constraints.each do |property, constraint|
			case [property, constraint]
			in [:length | :size, Range]
				schema[max_key] = range_end(constraint) if constraint.end
				schema[min_key] = constraint.begin if constraint.begin
			in [:length | :size, Integer]
				schema[max_key] = constraint
				schema[min_key] = constraint
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
