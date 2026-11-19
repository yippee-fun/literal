# frozen_string_literal: true

class Literal::Serializer::NilableType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableNilable"
	end

	def ===(value)
		nil === value
	end

	def matches?(other)
		Literal::Types::NilableType === other || nil === other
	end
end

class Literal::NilableSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::NilableType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type)
	end

	def child_types(type)
		case type
		when Literal::Types::NilableType
			[type.type]
		else
			[]
		end
	end

	def json_type(type)
		"null" unless Literal::Types::NilableType === type
	end

	def json_schema(type, generator: nil)
		return { "type" => "null" } if type.nil?
		return { "type" => "null" } if Literal::Serializer::NilableType === type

		{
			"anyOf" => [
				json_schema_for(type.type, generator:),
				{ "type" => "null" },
			],
		}
	end

	def serialize(value, type:)
		case value
		when nil
			nil
		else
			serialize_contents(value, type: type.type)
		end
	end

	def deserialize(raw, type:)
		case raw
		when nil
			nil
		else
			deserialize_contents(raw, type: type.type)
		end
	end
end
