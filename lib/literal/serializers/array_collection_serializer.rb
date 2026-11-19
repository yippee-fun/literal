# frozen_string_literal: true

class Literal::Serializer::ArrayCollectionType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableLiteralArray"
	end

	def ===(value)
		Literal::Array === value
	end

	def matches?(other)
		case other
		when Literal::Array::Generic
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Array::Generic === constraint }
		else
			false
		end
	end
end

class Literal::ArrayCollectionSerializer < Literal::Serializer::CollectionSerializer
	def initialize(context)
		super
		@type = Literal::Serializer::ArrayCollectionType.new(@context)
	end

	attr_reader :type

	def generic_class
		Literal::Array::Generic
	end

	def reconstruct(value)
		Literal.Array(value.__type__)
	end
end
