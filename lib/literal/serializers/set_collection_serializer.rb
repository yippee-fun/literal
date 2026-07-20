# frozen_string_literal: true

class Literal::Serializer::SetCollectionType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableLiteralSet"
	end

	def ===(value)
		Literal::Set === value
	end

	def matches?(other)
		case other
		when Literal::Set::Generic
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Set::Generic === constraint }
		else
			false
		end
	end
end

class Literal::SetCollectionSerializer < Literal::Serializer::CollectionSerializer
	def initialize(context)
		super
		@type = Literal::Serializer::SetCollectionType.new(@context)
	end

	attr_reader :type

	def generic_class
		Literal::Set::Generic
	end

	def reconstruct(value)
		Literal.Set(value.__type__)
	end
end
