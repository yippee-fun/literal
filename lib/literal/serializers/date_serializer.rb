# frozen_string_literal: true

class Literal::DateSerializer < Literal::Serializer
	Tag = :date
	Type = Date

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		case type
		when Date
			{ "type" => "string", "format" => "date", "const" => serialize_date(type) }
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string", "format" => "date" }
		end
	end

	def serialize(value, type:)
		serialize_date(value)
	end

	def deserialize(raw, type:)
		Date.parse(raw)
	end

	private def constraint_json_schema(type)
		{ "type" => "string", "format" => "date" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Date
					schema["const"] = serialize_date(constraint)
				when Range
					schema["minimum"] = serialize_date(constraint.begin) if constraint.begin

					if constraint.end
						if constraint.exclude_end?
							schema["exclusiveMaximum"] = serialize_date(constraint.end)
						else
							schema["maximum"] = serialize_date(constraint.end)
						end
					end
				end
			end
		end
	end

	private def serialize_date(value)
		value.strftime("%Y-%m-%d")
	end
end
