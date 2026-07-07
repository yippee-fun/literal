# frozen_string_literal: true

# Shared member classification for the union kind and serializer: which
# members can actually hold values, and the integer and finite float pairing
# that collapses to JSON "number".
module Literal::Serializer::UnionClassification
	FiniteFloatType = Literal::Types._Float(finite?: true)

	# The members a value could actually inhabit. _Never members can end up in
	# programmatically built unions, but no value or raw JSON ever belongs to
	# one, so classification, schema generation and dispatch all ignore them.
	private def inhabited_members(type)
		type.to_a.reject { |member| Literal::Types::NeverType === member }
	end

	# A two-member union of Integer and a finite Float, which serializes as a
	# single JSON "number" because JSON cannot tell 1 from 1.0.
	private def number_union?(type)
		members = inhabited_members(type)

		members.length == 2 && integer_and_finite_float_members?(members)
	end

	private def integer_and_finite_float?(type)
		integer_and_finite_float_members?(inhabited_members(type))
	end

	private def integer_and_finite_float_members?(members)
		members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float_type?(member) }
	end

	private def finite_float_type?(type)
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
	end
end
