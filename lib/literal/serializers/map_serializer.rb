# frozen_string_literal: true

class Literal::Serializer::MapType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableMap"
	end

	def matches?(other)
		Literal::Types::MapType === other
	end
end

class Literal::MapSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::MapType.new(@context)
	end

	attr_reader :type

	# Map keys become JSON object keys, so they must be Symbols or Strings
	# naming distinct keys in UTF-8.
	def handles_type?(type)
		return false unless @type.matches?(type)

		keys = type.shape.keys.map { |key| json_key(key) }
		keys.all? && keys.uniq.size == keys.size
	end

	def rejection_reason(type)
		if @type.matches?(type) && !handles_type?(type)
			"its keys must be Symbols or Strings naming distinct UTF-8 JSON object keys"
		end
	end

	def child_types(type)
		type.shape.values.map { |value_type| without_undefined(value_type) }
	end

	def referenceable?(type)
		true
	end

	def json_type(type)
		"object"
	end

	def object_shape(type)
		required = Set[]
		allowed = Set[]
		const_domains = {}

		type.shape.each do |key, value_type|
			name = json_key(key)
			allowed << name
			required << name unless value_type === nil || undefined_optional?(value_type)

			if (domain = @context.const_domain(without_undefined(value_type)))
				const_domains[name] = domain
			end
		end

		Literal::Serializer::ObjectShape.new(required:, allowed:, const_domains:)
	end

	def json_schema(type, generator: nil)
		{
			"type" => "object",
			"properties" => type.shape.to_h do |key, value_type|
				[json_key(key), json_schema_for(without_undefined(value_type), generator:)]
			end,
			"required" => object_shape(type).required.to_a,
			"additionalProperties" => false,
		}
	end

	def mergeable_object?(type)
		Literal::Types::MapType === type && type.shape.each_key.none? { |key| json_key(key) == "$type" }
	end

	def serialize(value, type:)
		type.shape.filter_map do |key, value_type|
			item = value[key]
			next if undefined_optional?(value_type) && Literal::Undefined == item

			[json_key(key), serialize_contents(item, type: without_undefined(value_type))]
		end.to_h
	end

	def deserialize(raw, type:)
		type.shape.to_h do |key, value_type|
			name = json_key(key)

			if undefined_optional?(value_type) && !raw.key?(name)
				# An undefined value is omitted when serialized, so a missing key
				# deserializes back to Literal::Undefined.
				[key, Literal::Undefined]
			else
				[key, deserialize_contents(raw[name], type: without_undefined(value_type))]
			end
		end
	end

	private def json_key(key)
		case key
		in Symbol then utf8(key.name)
		in String then utf8(key)
		else nil
		end
	end

	# JSON text is UTF-8, so keys are named, compared and looked up in UTF-8,
	# and a key UTF-8 can't represent has no name.
	private def utf8(name)
		name = name.encode(Encoding::UTF_8) unless Encoding::UTF_8 == name.encoding
		name if name.valid_encoding?
	rescue EncodingError
		nil
	end
end
