# frozen_string_literal: true

module Literal
	module JsonSchema
		# Handles mapping between Literal types and JSON Schema types
		class TypeMapper
			class << self
				def map_type(type)
					if type == String || type == Symbol
						{ type: "string" }
					elsif type.is_a?(Types::NilableType)
						map_type(type.type)
					elsif type == Integer
						{ type: "integer" }
					elsif type == Float || type == Numeric
						{ type: "number" }
					elsif type == NilClass
						{ type: "null" }
					elsif type.is_a? Literal::Array::Generic
						map_array(type)
					elsif type.is_a? Literal::Hash::Generic
						map_object(type)
					elsif type.is_a? Range
						map_range(type)
					elsif type == TrueClass || type == TrueClass || type.is_a?(Literal::Types::BooleanType)
						{ type: "boolean" }
					elsif type.is_a?(Literal::Enum) || type <= Literal::Enum
						map_enum(type)
					elsif Time >= type
						{ type: "string", format: "date-time" }
					elsif Date >= type
						{ type: "string", format: "date" }
					else
						{ type: "object" }
					end
				end

				private

				def map_range(range)
					schema = { type: range.begin.is_a?(Integer) ? "integer" : "number" }
					schema[:minimum] = range.begin unless range.begin.nil?
					schema[:maximum] = range.end unless range.end.nil?
					schema[:exclusiveMaximum] = true if range.exclude_end?
					schema
				end

				def map_array(array_type)
					{
						type: "array",
						items: map_type(array_type.type),
					}
				end

				def map_object(hash_type)
					{
						type: "object",
						additionalProperties: map_type(hash_type.value_type),
					}
				end

				def map_enum(enum_type)
					values = enum_type.values
					{
						type: "string",
						enum: values.map(&:to_s),
					}
				end
			end
		end
	end
end
