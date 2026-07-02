# frozen_string_literal: true

require "set"

class Literal::Serializer::SerializableType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		@type.inspect
	end

	def ===(value)
		@type === value
	end

	def >=(other, context: nil)
		serializable?(other) && Literal.subtype?(other, @type, context:)
	end

	def serializable?(type)
		serializable_type?(type)
	end

	private def serializable_type?(type, stack: Set[], seen: Set[])
		type = type.materialize if type in Literal::Types::DeferredType
		key = type.object_id

		return dereferenceable_type?(type) if stack.include?(key)
		return true if seen.include?(key)
		return true unless type.respond_to?(:literal_child_types)

		stack.add(key)

		type.literal_child_types.all? do |child_type|
			serializable_type?(child_type, stack:, seen:)
		end
	ensure
		if key
			stack.delete(key)
			seen.add(key)
		end
	end

	private def dereferenceable_type?(type)
		Class === type && type < Literal::DataStructure && type.name
	end
end
