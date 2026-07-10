# frozen_string_literal: true

class Literal::RangeSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = _Range(@context.type)
	end

	attr_reader :type

	def handles_type?(type)
		!range_type_for(type).nil?
	end

	def child_types(type)
		[bound_type(type)]
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"object"
	end

	def object_shape(type)
		Literal::Serializer::ObjectShape.new(
			required: Set["from", "to", "inclusive"],
			allowed: Set["from", "to", "inclusive"],
			const_domains: {},
		)
	end

	def mergeable_object?(type)
		true
	end

	def json_schema(type, generator: nil)
		bound = bound_type(type)

		{
			"type" => "object",
			"properties" => {
				"from" => json_schema_for(bound, generator:),
				"to" => json_schema_for(bound, generator:),
				"inclusive" => { "type" => "boolean" },
			},
			"required" => ["from", "to", "inclusive"],
			"additionalProperties" => false,
		}
	end

	def serialize(value, type:)
		bound = bound_type(type)

		{
			"from" => serialize_contents(value.begin, type: bound),
			"to" => serialize_contents(value.end, type: bound),
			"inclusive" => !value.exclude_end?,
		}
	end

	def deserialize(raw, type:)
		bound = bound_type(type)
		from = deserialize_contents(raw["from"], type: bound)
		to = deserialize_contents(raw["to"], type: bound)

		if raw.fetch("inclusive")
			from..to
		else
			from...to
		end
	end

	# A bound is nil when the range is beginless or endless, so bounds
	# serialize as the nilable member type.
	private def bound_type(type)
		_Nilable(range_type_for(type).type)
	end

	private def range_type_for(type)
		case type
		when Literal::Types::RangeType
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::RangeType === constraint }
		end
	end
end
