# frozen_string_literal: true

class Literal::StringSerializer < Literal::Serializer
	Tag = :string
	Type = String

	def tag
		Tag
	end

	def type
		Type
	end

	def json_schema(type)
		case type
		when Literal::JSONSchema::StringType
			type.json_schema
		when String
			{ "type" => "string", "const" => type }
		when Literal::Types::UnionType
			union_json_schema(type)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string" }
		end
	end

	def serialize(value, type:)
		value
	end

	def deserialize(raw, type:)
		raw
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end

	private def union_json_schema(type)
		if type.types.empty?
			{ "type" => "string", "enum" => type.primitives.to_a }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Regexp
					if defined? JsRegex
						schema["pattern"] = JsRegex.new(constraint, target: "ES2018").to_s
					end
				end
			end

			type.property_constraints.each do |property, constraint|
				case [property, constraint]
				in [:length, Range]
					schema["maxLength"] = range_end(constraint) if constraint.end
					schema["minLength"] = constraint.begin if constraint.begin
				in [:length, Integer]
					schema["maxLength"] = constraint
					schema["minLength"] = constraint
				end
			end
		end
	end
end
