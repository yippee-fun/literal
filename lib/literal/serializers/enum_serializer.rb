# frozen_string_literal: true

class Literal::EnumSerializer < Literal::Serializer
	def type = Literal::Enum

	# An enum class, or one of its members used as a constant type. Unions of
	# members are left to the union serializer, which discriminates them by
	# value, since members of different enums can have different backing types.
	def handles_type?(type)
		Literal::Enum === type || within_domain?(type, Literal::Enum)
	end

	def child_types(type)
		[backing_type(type)]
	end

	def json_type(type)
		json_type_for(backing_type(type))
	end

	def value_type(value)
		value.class if Literal::Enum === value
	end

	def json_schema(type, generator: nil)
		backing = backing_type(type)
		values = backing_values(type).map { |value| serialize_contents(value, type: backing) }

		{ **json_schema_for(backing, generator:), "enum" => values }
	end

	def serialize(value, type:)
		serialize_contents(value.value, type: backing_type(type))
	end

	def deserialize(data, type:)
		enum = enum_class(type)

		enum[deserialize_contents(data, type: backing_type(type))] ||
			json_equal_member(enum, data) ||
			raise(malformed_raw_error(data, type))
	end

	# The wire can't tell [1] from [1.0], so a value no member holds exactly
	# loads as the member it's equal to in JSON.
	private def json_equal_member(enum, data)
		key = Literal::Serializer.json_equality_key(data)
		enum.each.find { |member| @context.const_domain(member).include?(key) }
	end

	private def backing_values(type)
		case type
		when Literal::Enum
			[type.value]
		else
			type.values
		end
	end

	private def enum_class(type)
		case type
		when Literal::Enum
			type.class
		else
			type
		end
	end

	private def backing_type(type)
		enum_class(type).literal_properties[:value].type
	end
end
