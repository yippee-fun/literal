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

test "a cyclic value re-entering the same deferred type does not match" do
	union = _Union(nil, _Array(_Deferred { union }))
	array = []
	array << array

	refute union === array
	assert union === [[], [nil]]
end

test "a cyclic value through a recursive tagged union does not match" do
	tagged = _TaggedUnion(leaf: Integer, branch: _Array(_Deferred { tagged }))
	array = [1]
	array << array

	refute tagged === array
	assert tagged === [1, [2, []]]
end

test "a cyclic value through a recursive hash does not match" do
	recursive = _Hash(String, _Deferred { recursive })
	hash = {}
	hash["self"] = hash

	refute recursive === hash
end
