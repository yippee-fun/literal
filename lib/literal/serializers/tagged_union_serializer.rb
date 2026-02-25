# frozen_string_literal: true

class Literal::TaggedUnionSerializer < Literal::Serializer
	Tag = :tagged_union

	def initialize(context)
		@context = context
		@type = _Union(@context.type)
		@kind = _Predicate("SerializableTaggedUnion") do |type|
			Literal::Types::TaggedUnionType === type && type.members.each_value.all? { |member_type| @context.kind === member_type }
		end
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

	def serialize(value, type:)
		tag, member_type = type.resolve(value)

		[tag.name, @context.serialize(value, type: member_type)]
	end

	def deserialize(raw, type:)
		tag, value = raw
		member_type = type[tag.to_sym]

		@context.deserialize(value, type: member_type)
	end
end
