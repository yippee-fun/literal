# frozen_string_literal: true

class Literal::DateSerializer < Literal::Serializer
	Type = Date
	Format = /\A(\d{4})-(\d{2})-(\d{2})\z/

	def type
		Type
	end

	def json_type(type)
		"string"
	end

	def json_schema(type, generator: nil)
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
		if String === raw && (match = Format.match(raw))
			year, month, day = match.captures.map(&:to_i)
			return Date.new(year, month, day) if Date.valid_date?(year, month, day)
		end

		raise Literal::ArgumentError, "Value #{raw.inspect} is not an RFC 3339 date and cannot be deserialized as #{type.inspect}"
	end

	private def constraint_json_schema(type)
		{ "type" => "string", "format" => "date" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Date
					schema["const"] = serialize_date(constraint)
				end
			end
		end
	end

	private def serialize_date(value)
		value.strftime("%Y-%m-%d")
	end
end
