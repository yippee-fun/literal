# frozen_string_literal: true

include Literal::Types

test "===" do
	assert numeric_kind = _Kind(Numeric)
	assert numeric_kind === Numeric
	assert numeric_kind === Integer
	assert numeric_kind === 1
	assert numeric_kind === _Integer(1..)
	assert numeric_kind === _Intersection(Integer, 1..5)
	assert numeric_kind === _Constraint(Integer, odd?: true)
	assert numeric_kind === Float
	assert numeric_kind === _Union(Integer, Float)
	assert numeric_kind === _Never
	assert numeric_kind === _Intersection(Integer, Numeric)
	assert numeric_kind === _Deferred { Integer }

	refute numeric_kind === String
	refute numeric_kind === _Union(Integer, String)
	refute numeric_kind === _Union(Integer, nil)
	refute numeric_kind === _Nilable(Integer)
	refute numeric_kind === _Intersection(String, _Any?)
	refute numeric_kind === _Deferred { String }

	assert _Kind(Module) === Class
	assert _Kind(Module) === Module
	refute _Kind(String) === Class

	assert _Kind(_Array(Integer)) === _Array(1)
	assert _Kind(_Array(numeric_kind.type)) === _Array(1)
end
