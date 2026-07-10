# frozen_string_literal: true

require "date"
require "time"

class Literal::TimeSerializer < Literal::Serializer
	Type = _Union(Time, DateTime)

	def type
		Type
	end

	def handles_type?(type)
		case type
		when Time, DateTime
			true
		else
			super
		end
	end

	def json_type(type)
		"string"
	end

	def json_schema(type, generator: nil)
		case type
		when Time, DateTime
			{ "type" => "string", "format" => "date-time", "const" => serialize_time(type) }
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string", "format" => "date-time" }
		end
	end

	def serialize(value, type:)
		serialize_time(value)
	end

	def deserialize(raw, type:)
		if DateTime === type || Literal.subtype?(type, DateTime)
			DateTime.iso8601(raw)
		else
			Time.iso8601(raw)
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string", "format" => "date-time" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Time, DateTime
					schema["const"] = serialize_time(constraint)
				end
			end
		end
	end

	private def serialize_time(value)
		fraction = case value
			when Time
				value.subsec
			when DateTime
				value.sec_fraction
		end

		if fraction.zero?
			value.iso8601
		else
			value.iso8601(9)
		end
	end
end
