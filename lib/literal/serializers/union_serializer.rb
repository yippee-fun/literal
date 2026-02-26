# frozen_string_literal: true

class Literal::UnionSerializer < Literal::Serializer
	Tag = :union

	def initialize(context)
		@context = context
		@type = _Deferred { @context.type }
		@kind = _Predicate("SerializableUnionKind") do |union|
			next false unless Literal::Types::UnionType === union

			tags = Set[]

			union.each.all? do |member|
				begin
					tag = @context.tag_for_type(member)
				rescue Literal::ArgumentError
					next false
				end

				next false if tags.include?(tag)

				tags << tag
			end
		end
	end

	def tag
		Tag
	end

	attr_reader :type
	attr_reader :kind

	def serialize(value, type:)
		member_type = type.resolve(value)
		tag = @context.tag_for_type(member_type)

		[tag.name, serialize_contents(value, type: member_type)]
	end

	def deserialize(raw_value, type:)
		tag_name, raw_member_value = raw_value
		serializer = @context.serializer_for_tag(tag_name.to_sym)
		member_type = type.each.find { |member| serializer.kind === member }

		unless member_type
			raise Literal::ArgumentError, "No union member type for tag #{tag_name.inspect} in #{type.inspect}"
		end

		deserialize_contents(raw_member_value, type: member_type)
	end
end
