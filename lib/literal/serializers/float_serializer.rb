# frozen_string_literal: true

class Literal::FloatSerializer < Literal::Serializer
	Tag = :float
	Type = Float

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		case type
		when Literal::JSONSchema::NumberType
			type.json_schema
		when Float
			{ "type" => "number", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "number" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end

	def coerce(raw)
		case raw
		when Integer
			raw.to_f
		else
			raw
		end
	end

	private def union_json_schema(type)
		if type.types.empty?
			{ "type" => "number", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "number" }.tap do |schema|
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
