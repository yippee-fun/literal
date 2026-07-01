# frozen_string_literal: true

class Literal::SerializationContext
	include Literal::Types

	def initialize(*serializers)
		@type = _Deferred { @type }
		@kind = _Deferred { @kind }

		@serializers = serializers.map { |it| it.new(self) }.freeze
		@serializer_kinds = @serializers.to_h { |serializer| [serializer, _Kind(serializer.type)] }.freeze

		@type = _Union(*@serializers.map(&:type))
		@kind = _Union(*@serializer_kinds.values)

		freeze
	end

	attr_reader :serializers
	attr_reader :type
	attr_reader :kind

	def json_schema(type)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_for_type(type)
		serializer.json_schema(type)
	end

	def serialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_for_type(type)

		if strict && !(type === value)
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be serialized as #{type.inspect}"
		end

		serialized = serializer.serialize(value, type:)

		if strict && !(_JSONData? === serialized)
			raise Literal::ArgumentError, "Value #{value.inspect} was not serialized correctly"
		end

		serialized
	end

	def deserialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_for_type(type)
		value = serializer.coerce(value)

		if strict && !(_JSONData === value)
			raise Literal::ArgumentError, "Value #{value.inspect} is not valid JSON data and cannot be deserialized as #{type.inspect}"
		end

		deserialized = serializer.deserialize(value, type:)

		if strict && !(type === deserialized)
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be deserialized as #{type.inspect}"
		end

		deserialized
	end

	def serializer_for_type(type)
		if (serializer = serializer_matching_type(type))
			serializer
		else
			raise Literal::ArgumentError, "No serializer type #{type.inspect}"
		end
	end

	def serializer_kind(serializer)
		@serializer_kinds.fetch(serializer)
	end

	private def serializer_matching_type(type)
		@serializers.find { |it| serializer_kind(it) === type }
	end
end
