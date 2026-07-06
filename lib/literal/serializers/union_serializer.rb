# frozen_string_literal: true

class Literal::Serializer::UnionType
	include Literal::Serializer::Kind

	SafeNaturalJSONTypes = Set["string", "integer", "number", "boolean", "null"].freeze
	FiniteFloatType = Literal::Types._Float(finite?: true)

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

	# The match guard breaks the re-entrancy of degenerate self-referential
	# unions (a union whose member defers back to the union itself), whose
	# member classification would otherwise recurse forever. Re-entry answers
	# false, which correctly rejects such unions.
	def matches?(other)
		case other
		when Literal::Types::UnionType
			Literal.with_match_guard(self, other) { natural?(other) }
		when Literal::Types::ConstraintType
			Literal.with_match_guard(self, other) { natural_constraint?(other) }
		else
			false
		end
	end

	# A union is natural when each member maps to a distinct JSON type, so a
	# deserializer can resolve the member from the raw value alone. Integer and
	# number are only allowed together when the number member is a finite float,
	# in which case the pair collapses to "number".
	private def natural?(type)
		seen = Set[]
		has_integer = false
		number_is_finite_float = false

		distinct = type.each.all? do |member|
			json_type = @context.json_type(member)
			next false unless SafeNaturalJSONTypes.include?(json_type)

			case json_type
			when "integer"
				has_integer = true
			when "number"
				number_is_finite_float = finite_float_type?(member)
			end

			seen.add?(json_type)
		end

		distinct && (!numeric_ambiguous?(seen) || (has_integer && number_is_finite_float))
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
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
	end
end

class Literal::UnionSerializer < Literal::Serializer
	FiniteFloatType = Literal::Types._Float(finite?: true)

	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		(constrained_union(type) || type).to_a
	end

	def json_type(type)
		union = constrained_union(type) || type
		"number" if number_union?(union)
	end

	def value_type(value)
	end

	def json_schema(type, generator: nil)
		return constrained_union_json_schema(type, generator:) if Literal::Types::ConstraintType === type
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

	private def constrained_union_json_schema(type, generator:)
		json_schema_for(constrained_union(type), generator:).tap do |schema|
			apply_range_constraints(schema, type.object_constraints.select { |constraint| Range === constraint })
		end
	end

	private def constrained_union(type)
		return unless Literal::Types::ConstraintType === type

		type.object_constraints.find { |constraint| Literal::Types::UnionType === constraint }
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
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
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

		type.each.find { |member| json_type_for(member) == json_type } ||
			natural_number_member_type(json_type, type) ||
			raise(Literal::ArgumentError, "No union member type for JSON type #{json_type.inspect} in #{type.inspect}")
	end

	private def natural_number_member_type(json_type, type)
		return unless json_type == "integer"

		type.each.find { |member| json_type_for(member) == "number" }
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
