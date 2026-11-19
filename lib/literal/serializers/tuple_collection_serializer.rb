# frozen_string_literal: true

class Literal::Serializer::TupleCollectionType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableLiteralTuple"
	end

	def ===(value)
		Literal::Tuple === value
	end

	def matches?(other)
		case other
		when Literal::Tuple::Generic
			true
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal::Tuple::Generic === constraint }
		else
			false
		end
	end
end

class Literal::TupleCollectionSerializer < Literal::Serializer::CollectionSerializer
	def initialize(context)
		super
		@type = Literal::Serializer::TupleCollectionType.new(@context)
	end

	attr_reader :type

	def generic_class
		Literal::Tuple::Generic
	end

	def reconstruct(value)
		Literal.Tuple(*value.__types__)
	end
end
