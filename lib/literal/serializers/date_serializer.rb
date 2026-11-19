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

	# DateTime is a Date, but a date format cannot hold its time.
	def serialize(value, type:)
		if DateTime === value
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be serialized as #{type.inspect} without losing its time; use a DateTime type"
		end

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

	# RFC 3339 dates have four-digit years.
	private def serialize_date(value)
		serialized = value.strftime("%Y-%m-%d")

		unless Format.match?(serialized)
			raise Literal::ArgumentError, "Value #{value.inspect} has a year outside 0000-9999, which an RFC 3339 date cannot hold"
		end

		serialized
	end
end
