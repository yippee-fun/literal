# frozen_string_literal: true

require "set"

module Literal::Serializer::RecursiveType
	private def serializable_children?(type, children)
		@context.serializable_type?(type) &&
			children.all? { |child_type| serializable_child_type?(child_type, type) }
	end

	private def serializable_child_type?(type, root, stack: Set[])
		type = type.materialize if type in Literal::Types::DeferredType

		return dereferenceable_type?(type) if type.equal?(root)
		return true if Literal.subtype?(type, @context.type)
		return false unless type.respond_to?(:literal_child_types)

		key = type.object_id
		return false if stack.include?(key)

		stack.add(key)

		type.literal_child_types.all? do |child_type|
			serializable_child_type?(child_type, root, stack:)
		end
	ensure
		stack.delete(key) if key
	end

	private def dereferenceable_type?(type)
		(Class === type && type < Literal::DataStructure) ||
			Literal::Types::MapType === type ||
			Literal::Types::ArrayType === type ||
			Literal::Types::HashType === type ||
			Literal::Types::TupleType === type
	end
end
