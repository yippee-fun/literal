# frozen_string_literal: true

class Literal::Serializer::UnionType
	include Literal::Serializer::Kind
	include Literal::Serializer::UnionNumerics

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

	# A sentence naming the members that keep the union from being natural, or
	# nil when it is natural. This is the same walk matches? answers with, so
	# the explanation can never drift from the check.
	def ambiguity(type)
		case (reason = Literal.with_match_guard(self, type) { diagnose(type) })
		when false
			"#{type.inspect} refers back into itself, so its members cannot be classified"
		else
			reason
		end
	end

	# A union is natural when a deserializer can resolve the member from the
	# raw value alone. Each member must map to its own JSON type, with two
	# exceptions: integer and number may pair when the number member is a
	# finite float (the pair collapses to "number"), and several object
	# members may share a union when their key shapes are pairwise
	# distinguishable.
	private def natural?(type)
		diagnose(type).nil?
	end

	private def diagnose(type)
		members_by_json_type = type.each.group_by { |member| @context.json_type(member) }

		if (untyped = members_by_json_type[nil])
			return untyped_member_ambiguity(untyped.first)
		end

		members_by_json_type.each do |json_type, members|
			next if members.length == 1

			if json_type == "object"
				if (reason = object_ambiguity(members))
					return reason
				end
			else
				a, b = members
				return "#{a.inspect} and #{b.inspect} both serialize to JSON #{json_type} values, so raw values cannot be resolved to a member; use _TaggedUnion to discriminate them explicitly"
			end
		end

		numeric_ambiguity(members_by_json_type)
	end

	private def untyped_member_ambiguity(member)
		if @context.serializer_for?(member)
			"#{member.inspect} does not serialize to a single JSON type, so raw values cannot be resolved to a member"
		else
			"there is no serializer for #{member.inspect}"
		end
	end

	private def object_ambiguity(members)
		shapes = members.to_h { |member| [member, @context.object_shape(member)] }

		open_member, _shape = shapes.find { |_member, shape| shape.nil? }
		if open_member
			return "#{open_member.inspect} accepts arbitrary keys, so it cannot share an untagged union with another object member"
		end

		shapes.keys.combination(2) do |a, b|
			next if shapes.fetch(a).distinguishable_from?(shapes.fetch(b))

			return "#{a.inspect} and #{b.inspect} can match the same JSON objects; give one a required key the other does not allow, give a shared required key distinct constant values, or use _TaggedUnion"
		end

		nil
	end

	private def numeric_ambiguity(members_by_json_type)
		return unless members_by_json_type.key?("integer") && members_by_json_type.key?("number")

		number_member = members_by_json_type.fetch("number").find { |member| !finite_float_type?(member) }
		return unless number_member

		"Integer and #{number_member.inspect} both serialize to JSON number values, so raw values cannot be resolved to a member; only exactly _Float(finite?: true) can pair with Integer, collapsing the pair to a plain number"
	end

	private def natural_constraint?(type)
		object_constraints = type.object_constraints
		union = object_constraints.find { |constraint| Literal::Types::UnionType === constraint }
		return false unless union

		object_constraints.all? { |constraint| Range === constraint || constraint == union } &&
			integer_and_finite_float?(union) &&
			natural?(union)
	end
end

class Literal::UnionSerializer < Literal::Serializer
	include Literal::Serializer::UnionNumerics

	def initialize(context)
		@context = context
		@type = Literal::Serializer::UnionType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def rejection_reason(type)
		return unless Literal::Types::UnionType === type

		@type.ambiguity(type)
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

	private def json_schema_members(type, generator:)
		if integer_and_finite_float?(type)
			type.each.reject { |member| member == Integer || finite_float_type?(member) }
				.map { |member| json_schema_for(member, generator:) } << { "type" => "number" }
		else
			type.each.map { |member| json_schema_for(member, generator:) }
		end
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
		members = type.each.select { |member| json_type_for(member) == json_type }

		case members.length
		when 0
			natural_number_member_type(json_type, type) ||
				raise(Literal::ArgumentError, "No union member type for JSON type #{json_type.inspect} in #{type.inspect}")
		when 1
			members.first
		else
			# Only object members can share a JSON type in a natural union, and
			# their shapes are pairwise distinguishable, so at most one accepts.
			members.find { |member| @context.object_shape(member).accepts?(raw_value) } ||
				raise(Literal::ArgumentError, "No union member type for JSON object with keys #{raw_value.keys.inspect} in #{type.inspect}")
		end
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
		when Hash
			"object"
		when Array
			"array"
		end
	end
end
