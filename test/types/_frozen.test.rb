# frozen_string_literal: true

class FrozenTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Frozen(Array) === [].freeze
		assert _Frozen(String) === "immutable"

		refute _Frozen(Array) === []
		refute _Frozen(String) === +"mutable"
		refute _Frozen(Array) === nil
	end

	test "hierarchy" do
		assert_subtype _Constraint(Array, frozen?: true), _Frozen(Enumerable)
		assert_subtype Symbol, _Frozen(Symbol)
		assert_subtype Integer, _Frozen(Numeric)
		assert_subtype _Intersection(String, _Frozen(String)), _Frozen(String)
		assert_subtype _Intersection(String, _Frozen(Comparable)), _Frozen(String)

		refute_subtype String, _Frozen(String)
		refute_subtype Symbol, _Frozen(String)

		# Numeric can be subclassed by unfrozen user classes.
		refute_subtype Numeric, _Frozen(Numeric)
		refute_subtype _Constraint(Numeric, 1..), _Frozen(Numeric)

		# _Frozen can only vouch for frozen?, not other property constraints
		assert_subtype _Frozen(String), _Constraint(String, frozen?: true)
		refute_subtype _Frozen(String), _Constraint(String, length: 10)
		refute_subtype _Frozen(String), _Constraint(String, frozen?: true, length: 10)
	end
end
