# frozen_string_literal: true

class Literal::ArraySerializer < Literal::Serializer
	Tag = :array

	def initialize(context)
		super
		@type = _Array(@context.type)
	end

	def tag
		Tag
	end

	attr_reader :type

	def json_schema(type)
		{ "type" => "array" }.tap do |schema|
			case type
			when Literal::Types::ArrayType
				schema["items"] = json_schema_for(type.type)
			when Literal::Types::ConstraintType
				array_type = array_type_for(type)
				schema["items"] = json_schema_for(array_type.type)

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
		member_type = array_type_for(type).type

		value.map do |item|
			serialize_contents(item, type: member_type)
		end
	end

	def deserialize(raw, type:)
		member_type = array_type_for(type).type

		raw.map do |item|
			deserialize_contents(item, type: member_type)
		end
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end

	private def array_type_for(type)
		case type
		when Literal::Types::ArrayType
			type
		when Literal::Types::ConstraintType
			type.object_constraints.find { |constraint| Literal::Types::ArrayType === constraint }
		end
	end
end
