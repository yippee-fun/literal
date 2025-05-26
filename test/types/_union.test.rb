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
