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

test "a materialized _Deferred still matches once frozen" do
	type = _Deferred { String }
	assert type === "a"

	type.freeze

	assert type === "b"
	refute type === 1
end

test "a _Deferred frozen before it is used still matches" do
	type = _Deferred { String }.freeze

	assert type === "a"
	refute type === 1
end

test "a check made while a _Deferred is materializing gets an answer" do
	# Like a constant whose autoload checks a value against the type being resolved
	nested = nil
	runs = 0
	type = _Deferred do
		runs += 1
		nested = type === "a" if runs == 1
		String
	end

	assert type === "b"
	assert_equal nested, true
end
