# frozen_string_literal: true

class Literal::SetSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = _Set(@context.type)
	end

	attr_reader :type

	def json_schema(type, generator: nil)
		{ "type" => "array", "uniqueItems" => true }.tap do |schema|
			case type
			when Literal::Types::SetType
				schema["items"] = json_schema_for(type.type, generator:)
			when Literal::Types::ConstraintType
				set_type = set_type_for(type)
				schema["items"] = json_schema_for(set_type.type, generator:)

				type.property_constraints.each do |property, constraint|
					case [property, constraint]
					in [:length | :size, Range]
						schema["maxItems"] = range_end(constraint) if constraint.end
						schema["minItems"] = constraint.begin if constraint.begin
					in [:length | :size, Integer]
						schema["maxItems"] = constraint
						schema["minItems"] = constraint
					end
				end
			end
		end
	end

	def serialize(value, type:)
		member_type = set_type_for(type).type

		value.map do |item|
			serialize_contents(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		member_type = set_type_for(type).type

		raw.to_set do |item|
			deserialize_contents(item, type: member_type)
		end
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end

	private def set_type_for(type)
		case type
		when Literal::Types::SetType
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::SetType === constraint }
		end
	end
end
