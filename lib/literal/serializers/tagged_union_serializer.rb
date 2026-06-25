# frozen_string_literal: true

class Literal::Serializer::TaggedUnionType
	include Literal::Type
	include Literal::Types

	def initialize(context)
		@context = context
		@type = _Union(@context.type)
		freeze
	end

	def inspect
		"SerializableTaggedUnion"
	end

	def ===(value)
		@type === value
	end

	def >=(other, context: nil)
		Literal::Types::TaggedUnionType === other && other.members.each_value.all? { |member_type| Literal.subtype?(member_type, @context.type, context:) }
	end
end

class Literal::TaggedUnionSerializer < Literal::Serializer
	Tag = :tagged_union

	def initialize(context)
		@context = context
		@type = Literal::Serializer::TaggedUnionType.new(@context)
		@kind = _Kind(@type)
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

	def serialize(value, type:)
		tag, member_type = type.resolve(value)

		[tag.name, serialize_contents(value, type: member_type)]
	end

	def deserialize(raw, type:)
		tag, value = raw
		member_type = type[tag.to_sym]

		deserialize_contents(value, type: member_type)
	end
end
