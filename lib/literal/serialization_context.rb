# frozen_string_literal: true

class Literal::SerializationContext
	include Literal::Types

	def initialize(*serializers)
		@type = _Deferred { @type }
		@kind = _Deferred { @kind }

		@serializers = serializers.map { |it| it.new(self) }.freeze
		ordered_serializers = @serializers.sort_by { |serializer| type_order(serializer) }

		@type = _TaggedUnion(**ordered_serializers.to_h { |serializer| [serializer.tag, serializer.type] })
		@kind = _Union(*@serializers.map(&:kind))

		@map = @serializers.to_h { |it| [it.tag, it] }.freeze

		freeze
	end

	attr_reader :serializers
	attr_reader :type
	attr_reader :kind

	def serialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType
		return nil if nil === value && type === nil

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
		return nil if nil === value && type === nil

		serializer = serializer_for_type(type)

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
		if (serializer = @serializers.find { |it| it.kind === type })
			serializer
		else
			raise Literal::ArgumentError, "No serializer type #{type.inspect}"
		end
	end

	def tag_for_type(type)
		serializer_for_type(type).tag
	end

	def serializer_for_tag(tag)
		if (serializer = @map[tag])
			serializer
		else
			raise Literal::ArgumentError, "No serializer for tag #{tag.inspect}"
		end
	end

	private

	def type_order(serializer)
		case serializer.tag
		when :nilable
			2
		when :union
			3
		when :tagged_union
			4
		else
			1
		end
	end

end
