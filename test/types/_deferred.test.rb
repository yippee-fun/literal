# frozen_string_literal: true

include Literal::Types

test "===" do
	recursive = _Hash(
		String,
		_Deferred { recursive }
	)

	assert recursive === {
		"a" => {
			"b" => {
				"c" => {
					"d" => {
						"e" => {
							"f" => {
								"g" => {},
							},
						},
					},
				},
			},
		},
	}

	refute recursive === {
		"a" => {
			"b" => { 1 => {} },
		},
	}
end

test "hirearchy" do
	assert_subtype Integer, _Deferred { Numeric }
	assert_subtype _Deferred { Integer }, _Deferred { Numeric }
end

test "hierarchy with recursive deferred union does not recurse forever" do
	recursive = _Union(Integer, _Nilable(_Deferred { recursive }))

	assert_subtype Integer, recursive
	refute_subtype Proc, recursive
	assert_equal false, Literal.subtype?(Proc, recursive)
end

test "subtype in-progress guard keeps parent lock" do
	recursive = _Union(Integer, _Nilable(_Deferred { recursive }))

	3.times do
		assert_equal false, Literal.subtype?(Proc, recursive)
	end
end

test "subtype handles deferred fresh-wrapper cycles" do
	recursive = _Deferred { _Nilable(recursive) }

	assert_equal false, Literal.subtype?(Proc, recursive)
end
