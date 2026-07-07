# frozen_string_literal: true

include Literal::Types

def expect_type_error(expected:, actual:, message:)
	error = assert_raises(Literal::TypeError) do
		Literal.check(expected:, actual:)
	end

	assert_equal error.message, message
end

test "#enumerability" do
	union = _Union(:a, :b, :c, 1, 2, 3, String, Integer)

	assert_equal union.to_a, [:a, :b, :c, 1, 2, 3, String, Integer]
end

test "#deconstruct" do
	union = _Union(:a, :b, :c, 1, 2, 3, String, Integer)

	assert_equal union.deconstruct, [:a, :b, :c, 1, 2, 3, String, Integer]
end

test "#[]" do
	union = _Union(:a, :b, :c, 1, 2, 3, String, Integer)

	assert_equal union[:a], :a
	assert_equal union[:b], :b
	assert_equal union[:c], :c
	assert_equal union[1], 1
	assert_equal union[2], 2
	assert_equal union[3], 3
	assert_equal union[String], String
	assert_equal union[Integer], Integer

	assert_equal union[:d], nil
end

test "#fetch" do
	union = _Union(:a, :b, :c, 1, 2, 3, String, Integer)

	assert_equal union.fetch(:a), :a
	assert_equal union.fetch(:b), :b
	assert_equal union.fetch(:c), :c
	assert_equal union.fetch(1), 1
	assert_equal union.fetch(2), 2
	assert_equal union.fetch(3), 3
	assert_equal union.fetch(String), String
	assert_equal union.fetch(Integer), Integer

	assert_raises(KeyError) { union.fetch(:d) }
end

test "#reject" do
	assert_equal _Union(String, Literal::Undefined).reject { |type| type == Literal::Undefined }, String
	assert_equal _Union(String, Integer, Literal::Undefined).reject { |type| type == Literal::Undefined }.inspect, "_Union(String, Integer)"
	assert_equal _Union(String, Literal::Undefined).reject { |_type| true }, _Never
end

test "never members are removed" do
	assert_equal _Union(String, Integer, _Never).to_a, [String, Integer]
	assert_equal _Union(String, Integer, _Never).inspect, "_Union(String, Integer)"
	assert_equal _Union(String, _Union(Integer, _Never)).to_a, [String, Integer]

	assert_subtype _Never, _Union(String, Integer, _Never)
	refute _Union(String, Integer, _Never) === nil
end

test "a union of only never members is never" do
	assert_equal _Union(_Never), _Never
	assert_equal _Union(_Never, _Never), _Never
	assert_equal _Union(_Never, _Union(_Never)), _Never
end

test "a union containing any-nilable is any-nilable" do
	assert_equal _Union(String, _Any?), _Any?
	assert_equal _Union(String, _Nilable(_Any)), _Any?
	assert_equal _Union(_Any?, _Never), _Any?
end

test "a union does not absorb void" do
	assert_equal _Union(String, _Void).to_a, [String, _Void]
end

test "a union with a single member is that member" do
	assert_equal _Union(String), String
	assert_equal _Union(String, String), String
	assert_equal _Union(String, _Never), String
	assert_equal _Union(:a, _Union(:a)), :a
end

test "hierarchy" do
	assert_subtype _Union(:a), _Union(:a)
	assert_subtype _Union(:a, :b, :c), _Union(:a, :b, :c)
	assert_subtype _Union(:a, :b, :c), _Union(:a, :b, :c, :d)

	assert_subtype _Union(Integer), _Union(Numeric)
	assert_subtype Integer, _Union(Numeric)
	assert_subtype 1, _Union(Integer)
	assert_subtype _Union(1, 2, 3), _Union(Integer)
end

test "===" do
	position = _Union(:top, :right, :bottom, :left, Integer)

	assert position === :top
	assert position === :right
	assert position === :bottom
	assert position === :left
	assert position === 42

	refute position === :center
	refute position === "top"
end

test "other unions are flattened" do
	type = _Union(
		_Union(String, Integer),
		_Union(Symbol, Float),
	)

	assert_equal type.inspect, "_Union(String, Integer, Symbol, Float)"
end

test "error message" do
	error = assert_raises Literal::TypeError do
		Literal.check(:symbol, _Union(String, Integer))
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		  Expected: _Union(String, Integer)
		  Actual (Symbol): :symbol
	ERROR
end
