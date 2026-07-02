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
		return natural_constraint?(other) if Literal::Types::ConstraintType === other
		return false unless Literal::Types::UnionType === other

		natural?(other)
	end

	SafeNaturalJSONTypes = Set["string", "integer", "number", "boolean", "null"].freeze
	FiniteFloatType = Literal::Types._Float(finite?: true)

	private def natural?(type, generator: Literal::JSONSchema::Generator.new(@context))
		seen = Set[]
		has_integer = false
		number_member = nil

		type.each.all? do |member|
			json_type = natural_json_type(member, generator:)
			return false unless json_type

			case json_type
			when "integer"
				has_integer = true
			when "number"
				number_member = member
			end

			return false if seen.include?(json_type)

			seen << json_type
		end && (!numeric_ambiguous?(seen) || (has_integer && finite_float_type?(number_member)))
	end

	private def natural_json_type(type, generator:)
		schema = @context.json_schema(type, generator:)
		return unless Hash === schema

		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def natural_constraint?(type)
		object_constraints = type.object_constraints
		union = object_constraints.find { |constraint| Literal::Types::UnionType === constraint }
		return false unless union

		object_constraints.all? { |constraint| Range === constraint || constraint == union } &&
			integer_and_finite_float?(union) &&
			natural?(union)
	end

	private def numeric_ambiguous?(seen)
		seen.include?("integer") && seen.include?("number")
	end

	private def integer_and_finite_float?(type)
		members = type.to_a

		members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float_type?(member) }
	end

	private def finite_float_type?(type)
		equivalent_type?(type, FiniteFloatType)
	end

	private def equivalent_type?(subtype, supertype)
		Literal.subtype?(subtype, supertype) && Literal.subtype?(supertype, subtype)
	end
end

class Literal::UnionSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	attr_reader :type

	def value_type(value)
	end

	def json_schema(type, generator: nil)
		return constrained_union_json_schema(type, generator:) if constrained_union?(type)
		return { "type" => "number" } if number_union?(type)

		{
			"oneOf" => json_schema_members(type, generator:),
		}
	end

	def serialize(value, type:)
		type = constrained_union(type) || type
		member_type = type.resolve(value)
		serialize_contents(value, type: member_type)
	end

	def deserialize(raw_value, type:)
		type = constrained_union(type) || type

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
		end && (!numeric_ambiguous?(seen) || (has_integer && finite_float_type?(number_member)))
	end

	private def natural_json_type(type, generator:)
		schema = json_schema_for(type, generator:)
		return unless Hash === schema

		json_type = schema["type"]

		json_type if SafeNaturalJSONTypes.include?(json_type)
	end

	private def constrained_union_json_schema(type, generator:)
		json_schema_for(constrained_union(type), generator:).tap do |schema|
			apply_range_constraints(schema, type.object_constraints.select { |constraint| Range === constraint })
		end
	end

	private def constrained_union?(type)
		union = constrained_union(type)
		return false unless union

		integer_and_finite_float?(union) &&
			type.object_constraints.all? { |constraint| Range === constraint || constraint == union }
	end

	private def constrained_union(type)
		return unless Literal::Types::ConstraintType === type

		type.object_constraints.find { |constraint| Literal::Types::UnionType === constraint }
	end

	private def numeric_ambiguous?(seen)
		seen.include?("integer") && seen.include?("number")
	end

	private def number_union?(type)
		members = type.to_a

		members.length == 2 &&
			members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float_type?(member) }
	end

	private def json_schema_members(type, generator:)
		if integer_and_finite_float?(type)
			type.each.reject { |member| member == Integer || finite_float_type?(member) }
				.map { |member| json_schema_for(member, generator:) } << { "type" => "number" }
		else
			type.each.map { |member| json_schema_for(member, generator:) }
		end
	end

	private def integer_and_finite_float?(type)
		members = type.to_a

		members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float_type?(member) }
	end

	private def finite_float_type?(type)
		equivalent_type?(type, FiniteFloatType)
	end

	private def equivalent_type?(subtype, supertype)
		Literal.subtype?(subtype, supertype) && Literal.subtype?(supertype, subtype)
	end

	private def integer_and_finite_float_member_type(raw_value, type)
		case raw_value
		when Integer
			type.each.find { |member| member == Integer }
		when Float
			type.each.find { |member| finite_float_type?(member) }
		end || raise(Literal::ArgumentError, "No union member type for JSON value #{raw_value.inspect} in #{type.inspect}")
	end

	private def natural_member_type(raw_value, type)
		json_type = raw_json_type(raw_value)
		generator = Literal::JSONSchema::Generator.new(@context)

		type.each.find { |member| natural_json_type(member, generator:) == json_type } ||
			natural_number_member_type(json_type, type) ||
			raise(Literal::ArgumentError, "No union member type for JSON type #{json_type.inspect} in #{type.inspect}")
	end

	private def natural_number_member_type(json_type, type)
		return unless json_type == "integer"

		generator = Literal::JSONSchema::Generator.new(@context)
		type.each.find { |member| natural_json_type(member, generator:) == "number" }
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
