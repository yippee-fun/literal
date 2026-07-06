# frozen_string_literal: true

# Shared vocabulary for the union kind and the union serializer: the integer
# and finite float pairing that collapses to JSON "number", and the finite
# float check that makes the pairing safe.
module Literal::Serializer::UnionNumerics
	FiniteFloatType = Literal::Types._Float(finite?: true)

	# A two-member union of Integer and a finite Float, which serializes as a
	# single JSON "number" because JSON cannot tell 1 from 1.0.
	private def number_union?(type)
		type.to_a.length == 2 && integer_and_finite_float?(type)
	end

	private def integer_and_finite_float?(type)
		members = type.to_a

		members.any? { |member| member == Integer } &&
			members.any? { |member| finite_float_type?(member) }
	end

	private def finite_float_type?(type)
		Literal.subtype?(type, FiniteFloatType) && Literal.subtype?(FiniteFloatType, type)
	end
end
