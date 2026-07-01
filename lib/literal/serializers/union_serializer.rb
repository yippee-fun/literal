# frozen_string_literal: true

class Literal::Serializer::UnionType
	include Literal::Type

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableUnion"
	end

	def ===(value)
		@context.type === value
	end

	def >=(other, context: nil)
		return false unless Literal::Types::UnionType === other

		natural?(other)
	end

	SafeNaturalJSONTypes = Set["string", "integer", "number", "boolean", "null"].freeze
	FiniteFloatType = Literal::Types._Float(finite?: true)

	private def natural?(type)
		seen = Set[]
		has_integer = false
		number_member = nil

		type.each.all? do |member|
			json_type = natural_json_type(member)
			return false unless json_type

			case json_type
			when "integer"
				has_integer = true
			when "number"
				number_member = member
			end

			return false if seen.include?(json_type)

			seen << json_type
		end && (!numeric_ambiguous?(seen) || (has_integer && finite_float?(number_member)))
	end

	private def natural_json_type(type)
		schema = @context.json_schema(type)
		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def numeric_ambiguous?(seen)
		seen.include?("integer") && seen.include?("number")
	end

	private def finite_float?(type)
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
	end
end

class Literal::UnionSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	attr_reader :type

	def json_schema(type)
		return { "type" => "number" } if number_union?(type)

		{
			"oneOf" => json_schema_members(type),
		}
	end

	def serialize(value, type:)
		member_type = type.resolve(value)
		serialize_contents(value, type: member_type)
	end

	def deserialize(raw_value, type:)
		member_type = if number_union?(type)
			integer_and_finite_float_member_type(raw_value, type)
		else
			natural_member_type(raw_value, type)
		end

		deserialize_contents(raw_value, type: member_type)
	end

	SafeNaturalJSONTypes = Set["string", "integer", "number", "boolean", "null"].freeze
	FiniteFloatType = Literal::Types._Float(finite?: true)

	private def natural?(type)
		seen = Set[]
		has_integer = false
		number_member = nil

		type.each.all? do |member|
			json_type = natural_json_type(member)
			return false unless json_type

			case json_type
			when "integer"
				has_integer = true
			when "number"
				number_member = member
			end

			return false if seen.include?(json_type)

			seen << json_type
		end && (!numeric_ambiguous?(seen) || (has_integer && finite_float?(number_member)))
	end

	private def natural_json_type(type)
		schema = json_schema_for(type)
		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def numeric_ambiguous?(seen)
		seen.include?("integer") && seen.include?("number")
	end

	private def number_union?(type)
		members = type.to_a

		members.length == 2 &&
			members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float?(member) }
	end

	private def json_schema_members(type)
		if integer_and_finite_float?(type)
			type.each.reject { |member| member == Integer || finite_float?(member) }
				.map { |member| json_schema_for(member) } << { "type" => "number" }
		else
			type.each.map { |member| json_schema_for(member) }
		end
	end

	private def integer_and_finite_float?(type)
		members = type.to_a

		members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float?(member) }
	end

	private def finite_float?(type)
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
	end

	private def integer_and_finite_float_member_type(raw_value, type)
		case raw_value
		when Integer
			type.each.find { |member| member == Integer }
		when Float
			type.each.find { |member| finite_float?(member) }
		end || raise(Literal::ArgumentError, "No union member type for JSON value #{raw_value.inspect} in #{type.inspect}")
	end

	private def natural_member_type(raw_value, type)
		json_type = raw_json_type(raw_value)

		type.each.find { |member| natural_json_type(member) == json_type } ||
			natural_number_member_type(json_type, type) ||
			raise(Literal::ArgumentError, "No union member type for JSON type #{json_type.inspect} in #{type.inspect}")
	end

	private def natural_number_member_type(json_type, type)
		return unless json_type == "integer"

		type.each.find { |member| natural_json_type(member) == "number" }
	end

	private def raw_json_type(value)
		case value
		when String
			"string"
		when Integer
			"integer"
		when Float
			"number"
		when true, false
			"boolean"
		when nil
			"null"
		end
	end
end
