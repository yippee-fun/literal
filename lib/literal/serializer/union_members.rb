# frozen_string_literal: true

# Scalar serializers write a union with a type among its members as anyOf
# the members' schemas, so the serializability walk must see those members.
module Literal::Serializer::UnionMembers
	def child_types(type)
		case type
		in Literal::Types::UnionType unless type.types.empty?
			type.to_a
		else
			[]
		end
	end
end
