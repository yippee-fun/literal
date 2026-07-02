# frozen_string_literal: true

class Literal::SerializationContext
	include Literal::Types

	DefaultSerializers = [
		Literal::StringSerializer,
		Literal::SymbolSerializer,
		Literal::IntegerSerializer,
		Literal::JSONSchemaNumberSerializer,
		Literal::FloatSerializer,
		Literal::BooleanSerializer,
		Literal::DateSerializer,
		Literal::StructureSerializer,
		Literal::TaggedUnionSerializer,
		Literal::UnionSerializer,
		Literal::HashSerializer,
		Literal::MapSerializer,
		Literal::TupleSerializer,
		Literal::ArraySerializer,
		Literal::SetSerializer,
		Literal::NilableSerializer,
		Literal::JSONDataSerializer,
	].freeze

	def initialize(*serializers, defaults: true)
		serializers = [*serializers, *DefaultSerializers] if defaults

		@type = _Deferred { @type }
		@kind = _Deferred { @kind }

		@serializers = serializers.map { |it| it.new(self) }.freeze
		@serializer_kinds = @serializers.to_h { |serializer| [serializer, _Kind(serializer.type)] }.freeze

		@type = Literal::Serializer::SerializableType.new(_Union(*@serializers.map(&:type)))
		@kind = _Union(*@serializer_kinds.values)

		freeze
	end

	attr_reader :serializers
	attr_reader :type
	attr_reader :kind

	def json_schema(type, generator: nil, reference: true)
		generator ||= Literal::JSONSchema::Generator.new(self)
		generator.schema(type, reference:)
	end

	def serialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType

		if aggregate_type?(type)
			serializer, type = serializer_for_value(value)
		else
			serializer = serializer_for_type(type)
		end

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

	def serializable_type?(type)
		@type.serializable?(type)
	end

	def build_json_schema(type, generator:)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_for_type(type)
		serializer.json_schema(type, generator:)
	end

	private def serializer_matching_type(type)
		@serializers.find { |it| serializer_kind(it) === type }
	end

	private def serializer_for_value(value)
		@serializers.each do |serializer|
			if (type = serializer.value_type(value))
				return [serializer, type]
			end
		end

		raise Literal::ArgumentError, "Value #{value.inspect} cannot be serialized as #{@type.inspect}"
	end

	private def aggregate_type?(type)
		Literal::Serializer::SerializableType === type
	end
end
