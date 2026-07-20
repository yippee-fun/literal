# frozen_string_literal: true

class Literal::Serializer::HashCollectionType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableLiteralHash"
	end

	def ===(value)
		Literal::Hash === value
	end

	def matches?(other)
		case other
		when Literal::Hash::Generic
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Hash::Generic === constraint }
		else
			false
		end
	end
end

class Literal::HashCollectionSerializer < Literal::Serializer::CollectionSerializer
	def initialize(context)
		super
		@type = Literal::Serializer::HashCollectionType.new(@context)
	end

	attr_reader :type

	def generic_class
		Literal::Hash::Generic
	end

	def reconstruct(value)
		Literal.Hash(value.__key_type__, value.__value_type__)
	end
end
