# frozen_string_literal: true

class Literal::SetSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = _Set(@context.type)
	end

	attr_reader :type

	def handles_type?(type)
		!set_type_for(type).nil?
	end

	def child_types(type)
		[set_type_for(type).type]
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"array"
	end

	def value_type(value)
		if Literal::Set === value
			Literal.Set(value.__type__)
		elsif type === value
			type
		end
	end

	def json_schema(type, generator: nil)
		{ "type" => "array", "uniqueItems" => true }.tap do |schema|
			case type
			when Literal::Types::SetType, Literal::Set::Generic
				schema["items"] = json_schema_for(type.type, generator:)
			when Literal::Types::ConstraintType
				set_type = set_type_for(type)
				schema["items"] = json_schema_for(set_type.type, generator:)

				apply_length_constraints(schema, type.property_constraints, min_key: "minItems", max_key: "maxItems")
			end
		end
	end

	def serialize(value, type:)
		member_type = set_type_for(type).type
		source = (Literal::Set === value) ? value.__value__ : value

		source.map do |item|
			serialize_contents(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		resolved = set_type_for(type)

		result = raw.to_set do |item|
			deserialize_contents(item, type: resolved.type)
		end

		(Literal::Set::Generic === resolved) ? resolved.coerce(result) : result
	end

	private def set_type_for(type)
		case type
		when Literal::Types::SetType, Literal::Set::Generic
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::SetType === constraint || Literal::Set::Generic === constraint }
		end
	end
end
