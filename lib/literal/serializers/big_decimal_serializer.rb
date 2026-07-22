# frozen_string_literal: true

require "bigdecimal"

class Literal::BigDecimalSerializer < Literal::Serializer
	Type = _Constraint(BigDecimal, finite?: true)

	def type
		Type
	end

	def json_type(type)
		"string"
	end

	def rejection_reason(type)
		if BigDecimal == type
			"it admits non-finite values like NaN — use _BigDecimal(finite?: true) instead"
		end
	end

	def json_schema(type, generator: nil)
		case type
		when BigDecimal
			{ "type" => "string", "format" => "decimal", "const" => serialize_decimal(type) }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string", "format" => "decimal" }
		end
	end

	def serialize(value, type:)
		serialize_decimal(value)
	end

	def deserialize(raw, type:)
		BigDecimal(raw)
	end

	def coerce(raw)
		case raw
		when Integer, Float
			raw.to_s
		else
			raw
		end
	end

	private def union_json_schema(type, generator:)
		if type.primitives.empty? && type.types.all?(BigDecimal)
			{ "type" => "string", "format" => "decimal", "enum" => type.types.map { |member| serialize_decimal(member) } }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string", "format" => "decimal" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when BigDecimal
					schema["const"] = serialize_decimal(constraint)
				end
			end
		end
	end

	private def serialize_decimal(value)
		value.to_s("F")
	end
end
