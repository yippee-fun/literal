# frozen_string_literal: true

class Literal::SymbolSerializer < Literal::Serializer
	Type = Symbol

	def type
		Type
	end

	def json_schema(type, generator: nil)
		case type
		when Symbol
			{ "type" => "string", "const" => type.name }
		when Literal::Types::UnionType
			union_json_schema(type, generator:)
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string" }
		end
	end

	def serialize(value, type:)
		value.name
	end

	def deserialize(raw, type:)
		raw.to_sym
	end

	private def union_json_schema(type, generator:)
		if type.types.empty?
			{ "type" => "string", "enum" => type.primitives.map(&:name) }
		else
			{ "anyOf" => type.map { |member| json_schema_for(member, generator:) }.to_a }
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string" }.tap do |schema|
			type.property_constraints.each do |property, constraint|
				case [property, constraint]
				in [:length | :size, Range]
					schema["maxLength"] = range_end(constraint) if constraint.end
					schema["minLength"] = constraint.begin if constraint.begin
				in [:length | :size, Integer]
					schema["maxLength"] = constraint
					schema["minLength"] = constraint
				end
			end
		end
	end

	private def range_end(range)
		range.exclude_end? ? range.end - 1 : range.end
	end
end
