# frozen_string_literal: true

class Literal::IntegerSerializer < Literal::Serializer
	Tag = :integer
	Type = Integer

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		case type
		when Integer
			{ "type" => "integer", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "integer" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(value, type:)
		value
	end

	# If we can coerce a float to an integer without losing anything, we’ll accept it.
	def coerce(value)
		case value
		when Float
			coerced = value.to_i
			(coerced == value) ? coerced : value
		else
			value
		end
	end

	private def union_json_schema(type)
		if type.types.empty?
			{ "type" => "integer", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "integer" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Range
					schema["minimum"] = constraint.begin if constraint.begin

					if constraint.end
						if constraint.exclude_end?
							schema["exclusiveMaximum"] = constraint.end
						else
							schema["maximum"] = constraint.end
						end
					end
				end
			end
		end
	end
end
