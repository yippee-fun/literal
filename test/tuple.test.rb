# frozen_string_literal: true

include Literal::Types

# Asserts the two types are equivalent — each a subtype of the other.
def assert_type_equal(actual, expected)
	assert Literal.subtype?(actual, expected)
	assert Literal.subtype?(expected, actual)
end

# Generic

test "Generic#new creates a checked literal tuple" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	assert Literal::Tuple === tuple
	assert_equal tuple.to_a, ["a", 1]
end

test "Generic#new checks each position" do
	assert_raises(Literal::TypeError) do
		Literal::Tuple(String, Integer).new("a", "b")
	end

	assert_raises(Literal::TypeError) do
		Literal::Tuple(String, Integer).new(1, 1)
	end
end

test "Generic#new checks the length" do
	assert_raises(Literal::TypeError) do
		Literal::Tuple(String, Integer).new("a")
	end

	assert_raises(Literal::TypeError) do
		Literal::Tuple(String, Integer).new("a", 1, 2)
	end
end

test "a tuple requires at least one type" do
	assert_raises(Literal::ArgumentError) do
		Literal::Tuple()
	end
end

test "Generic#coerce converts a plain array" do
	tuple = Literal::Tuple(String, Integer).coerce(["a", 1])

	assert_equal tuple, Literal::Tuple(String, Integer).new("a", 1)

	assert_raises(Literal::TypeError) do
		Literal::Tuple(String, Integer).coerce(["a"])
	end

	assert_equal Literal::Tuple(String, Integer).coerce("nope"), nil
end

test "Generic#coerce passes matching literal tuples through unchanged" do
	tuple = Literal::Tuple(Integer, Integer).new(1, 2)

	assert_same Literal::Tuple(Integer, Integer).coerce(tuple), tuple
	assert_same Literal::Tuple(Numeric, Numeric).coerce(tuple), tuple
end

test "Generic#=== matches covariantly per position" do
	tuple = Literal::Tuple(Integer, String).new(1, "a")

	assert Literal::Tuple(Integer, String) === tuple
	assert Literal::Tuple(Numeric, String) === tuple

	refute Literal::Tuple(String, String) === tuple
	refute Literal::Tuple(Integer, String, Integer) === tuple
	refute Literal::Tuple(Integer, String) === [1, "a"]
end

test "Generic#== compares the types" do
	assert_equal Literal::Tuple(String, Integer), Literal::Tuple(String, Integer)
	refute_equal Literal::Tuple(String, Integer), Literal::Tuple(Integer, String)
	refute_equal Literal::Tuple(String, Integer), Literal::Tuple(String)
end

test "Generic subtyping is covariant per position" do
	assert Literal.subtype?(Literal::Tuple(Integer, Float), Literal::Tuple(Numeric, Numeric))
	refute Literal.subtype?(Literal::Tuple(Numeric, Numeric), Literal::Tuple(Integer, Float))
	refute Literal.subtype?(Literal::Tuple(Integer), Literal::Tuple(Integer, Integer))
end

test "literal tuple types and plain tuple types are never subtypes of each other" do
	refute Literal.subtype?(Literal::Tuple(Integer), _Tuple(Integer))
	refute Literal.subtype?(_Tuple(Integer), Literal::Tuple(Integer))
	refute _Tuple(Integer) === Literal::Tuple(Integer).new(1)
end

test "Generic#inspect" do
	assert_equal Literal::Tuple(String, Integer).inspect, "Literal::Tuple(String, Integer)"
end

# Construction

test "#initialize copies the input, so the caller's reference is harmless" do
	input = ["a", 1]
	tuple = Literal::Tuple(String, Integer).coerce(input)

	input[0] = 2

	assert_equal tuple.to_a, ["a", 1]
end

# Equality

test "#== is structural" do
	assert_equal Literal::Tuple(String, Integer).new("a", 1), Literal::Tuple(String, Integer).new("a", 1)
	refute_equal Literal::Tuple(String, Integer).new("a", 1), Literal::Tuple(String, Integer).new("a", 2)
	refute_equal Literal::Tuple(String, Integer).new("a", 1), ["a", 1]
end

test "#eql? requires the same types" do
	a = Literal::Tuple(String, Integer).new("a", 1)
	b = Literal::Tuple(String, Integer).new("a", 1)

	assert a.eql?(b)
	assert_equal a.hash, b.hash

	refute Literal::Tuple(Integer, Integer).new(1, 1).eql?(Literal::Tuple(Numeric, Numeric).new(1, 1))
end

test "#<=> compares against literal tuples and plain arrays" do
	tuple = Literal::Tuple(Integer, Integer).new(1, 2)

	assert_equal (tuple <=> Literal::Tuple(Integer, Integer).new(1, 3)), -1
	assert_equal (tuple <=> [1, 2]), 0
	assert_equal (tuple <=> "nope"), nil
end

# Reads

test "#[], #fetch, #first, #last, #size and #include?" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	assert_equal tuple[0], "a"
	assert_equal tuple[-1], 1
	assert_equal tuple[2], nil
	assert_equal tuple.fetch(1), 1
	assert_raises(IndexError) { tuple.fetch(2) }
	assert_equal tuple.first, "a"
	assert_equal tuple.last, 1
	assert_equal tuple.size, 2
	assert tuple.include?(1)
	refute tuple.include?(2)
end

test "#each yields elements and returns self" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)
	yielded = []

	assert_same tuple.each { |v| yielded << v }, tuple
	assert_equal yielded, ["a", 1]
end

test "#to_a and #to_ary return detached plain arrays, enabling splats and destructuring" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	plain = tuple.to_a
	assert_equal plain, ["a", 1]
	refute_same plain, tuple.__value__

	assert_equal [*tuple], ["a", 1]

	a, b = tuple
	assert_equal [a, b], ["a", 1]
end

test "#deconstruct supports pattern matching" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	matched = case tuple
	in [String => string, Integer => integer]
		[string, integer]
	end

	assert_equal matched, ["a", 1]
end

test "#inspect" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	assert_equal tuple.inspect, "Literal::Tuple(String, Integer)[\"a\", 1]"
end

# Checked mutations

test "#[]= checks the value against the type at that position" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	tuple[0] = "b"
	tuple[-1] = 2

	assert_equal tuple.to_a, ["b", 2]

	assert_raises(Literal::TypeError) { tuple[0] = 1 }
	assert_raises(Literal::TypeError) { tuple[1] = "c" }
	assert_equal tuple.to_a, ["b", 2]
end

test "#[]= never changes the length" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	assert_raises(IndexError) { tuple[2] = "b" }
	assert_raises(IndexError) { tuple[-3] = "b" }
	assert_raises(IndexError) { tuple[0..1] = "b" }
	assert_equal tuple.to_a, ["a", 1]
end

test "there are no length-changing methods" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)

	refute tuple.respond_to?(:push)
	refute tuple.respond_to?(:<<)
	refute tuple.respond_to?(:pop)
	refute tuple.respond_to?(:clear)
	refute tuple.respond_to?(:delete)
end

# Copying and freezing

test "#dup does not share storage with the original" do
	tuple = Literal::Tuple(String, Integer).new("a", 1)
	copy = tuple.dup

	copy[1] = 2

	assert_equal copy.to_a, ["a", 2]
	assert_equal tuple.to_a, ["a", 1]
end

test "#freeze freezes the underlying storage" do
	tuple = Literal::Tuple(String, Integer).new("a", 1).freeze

	assert tuple.frozen?
	assert_raises(FrozenError) { tuple[1] = 2 }
end

test "#clone of a frozen tuple is frozen" do
	tuple = Literal::Tuple(String, Integer).new("a", 1).freeze
	copy = tuple.clone

	assert copy.frozen?
	assert_raises(FrozenError) { copy[1] = 2 }
end

# Enumerable

test "supported Enumerable methods work" do
	tuple = Literal::Tuple(Integer, Integer, Integer).new(1, 2, 3)

	assert tuple.all? { |i| i > 0 }
	assert tuple.any?(&:even?)
	assert tuple.none? { |i| i > 3 }
	assert tuple.one?(&:even?)
	assert_equal tuple.find(&:even?), 2
	assert_equal tuple.reduce(:+), 6
	assert_equal tuple.each_with_index.to_a, [[1, 0], [2, 1], [3, 2]]
	assert Enumerable === tuple
end

test "unsupported Enumerable methods are removed" do
	tuple = Literal::Tuple(Integer, Integer).new(1, 2)

	%i[
		map
		flat_map
		select
		reject
		sort
		sort_by
		group_by
		partition
		zip
		tally
		entries
		lazy
		grep
		detect
		inject
		collect
		filter
		member?
		count
	].each do |method|
		refute tuple.respond_to?(method)
	end
end
