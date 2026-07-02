# frozen_string_literal: true

class Literal::Serializer
	extend Literal::Types
	include Literal::Types

	def initialize(context)
		@context = context
	end

	def serialize_contents(value, type:)
		@context.serialize(value, type:, strict: false)
	end

	def deserialize_contents(value, type:)
		@context.deserialize(value, type:, strict: false)
	end

	def json_schema_for(type, generator:, reference: true)
		@context.json_schema(type, generator:, reference:)
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
