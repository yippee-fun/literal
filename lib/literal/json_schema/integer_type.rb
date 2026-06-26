# frozen_string_literal: true

class Literal::JSONSchema::IntegerType < Literal::Data
	include Literal::Type

	prop :minimum, _Nilable(::Numeric)
	prop :exclusive_minimum, _Nilable(::Numeric)
	prop :maximum, _Nilable(::Numeric)
	prop :exclusive_maximum, _Nilable(::Numeric)
	prop :multiple_of, _Nilable(::Numeric)

	def inspect
		"Literal::JSONSchema::Integer(#{json_schema.inspect})"
	end

	def ===(value)
		return false unless ::Integer === value

		number_matches?(value)
	end

	def <=(other, context: nil)
		Literal.subtype?(::Integer, other, context:)
	end

	def json_schema
		{ "type" => "integer" }.tap do |schema|
			schema["minimum"] = minimum unless minimum.nil?
			schema["exclusiveMinimum"] = exclusive_minimum unless exclusive_minimum.nil?
			schema["maximum"] = maximum unless maximum.nil?
			schema["exclusiveMaximum"] = exclusive_maximum unless exclusive_maximum.nil?
			schema["multipleOf"] = multiple_of unless multiple_of.nil?
		end
	end

	private def number_matches?(value)
		return false if !minimum.nil? && value < minimum
		return false if !exclusive_minimum.nil? && value <= exclusive_minimum
		return false if !maximum.nil? && value > maximum
		return false if !exclusive_maximum.nil? && value >= exclusive_maximum
		return false if !multiple_of.nil? && value % multiple_of != 0

		true
	end
end
