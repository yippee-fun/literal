# frozen_string_literal: true

include Literal::Types

# Asserts the two types are equivalent — each a subtype of the other.
def assert_type_equal(actual, expected)
	assert Literal.subtype?(actual, expected)
	assert Literal.subtype?(expected, actual)
end

# Asserts `set` is a Literal::Set with exactly the given type and members.
def assert_literal_set(set, type:, members:)
	assert Literal::Set === set
	assert_type_equal set.__type__, type
	assert_equal set.__value__, ::Set.new(members)
end

# Generic

test "Generic#new creates a checked literal set" do
	set = Literal::Set(Integer).new(1, 2, 2, 3)

	assert_literal_set set, type: Integer, members: [1, 2, 3]
end

test "Generic#new raises when a member doesn't match the type" do
	assert_raises(Literal::TypeError) do
		Literal::Set(String).new("a", 1)
	end
end

test "Generic#coerce converts plain sets and arrays" do
	from_set = Literal::Set(Integer).coerce(::Set[1, 2])
	from_array = Literal::Set(Integer).coerce([1, 2, 2])

	assert_literal_set from_set, type: Integer, members: [1, 2]
	assert_literal_set from_array, type: Integer, members: [1, 2]

	assert_raises(Literal::TypeError) do
		Literal::Set(Integer).coerce(["a"])
	end
end

test "Generic#coerce passes matching literal sets through unchanged" do
	set = Literal::Set(Integer).new(1)

	assert_same Literal::Set(Integer).coerce(set), set
	assert_same Literal::Set(Numeric).coerce(set), set
	assert_equal Literal::Set(String).coerce(set), nil
end

test "Generic#=== matches covariantly" do
	assert Literal::Set(Integer) === Literal::Set(Integer).new(1)
	assert Literal::Set(Numeric) === Literal::Set(Integer).new(1)

	refute Literal::Set(Integer) === Literal::Set(Numeric).new(1)
	refute Literal::Set(Integer) === ::Set[1]
end

test "Generic#== compares member types" do
	assert_equal Literal::Set(Integer), Literal::Set(Integer)
	refute_equal Literal::Set(Integer), Literal::Set(String)
end

test "Generic subtyping is covariant" do
	assert Literal.subtype?(Literal::Set(Integer), Literal::Set(Numeric))
	refute Literal.subtype?(Literal::Set(Numeric), Literal::Set(Integer))
end

test "literal set types and plain set types are never subtypes of each other" do
	refute Literal.subtype?(Literal::Set(Integer), _Set(Integer))
	refute Literal.subtype?(_Set(Integer), Literal::Set(Integer))
	refute _Set(Integer) === Literal::Set(Integer).new(1)
end

test "Generic#inspect" do
	assert_equal Literal::Set(Integer).inspect, "Literal::Set(Integer)"
end

# Construction

test "#initialize copies the input, so the caller's reference is harmless" do
	input = ::Set[1, 2]
	set = Literal::Set(Integer).coerce(input)

	input << "3"

	assert_literal_set set, type: Integer, members: [1, 2]
end

# Equality

test "#== is structural" do
	assert_equal Literal::Set(Integer).new(1, 2), Literal::Set(Integer).new(2, 1)
	refute_equal Literal::Set(Integer).new(1), Literal::Set(Integer).new(2)
	refute_equal Literal::Set(Integer).new(1), ::Set[1]
end

test "#eql? requires the same type" do
	a = Literal::Set(Integer).new(1, 2)
	b = Literal::Set(Integer).new(1, 2)

	assert a.eql?(b)
	assert_equal a.hash, b.hash

	refute Literal::Set(Integer).new.eql?(Literal::Set(String).new)
end

# Reads

test "#size, #empty?, #include? and #each" do
	set = Literal::Set(Integer).new(1, 2)

	assert_equal set.size, 2
	refute set.empty?
	assert Literal::Set(Integer).new.empty?
	assert set.include?(2)
	refute set.include?(3)

	yielded = []
	assert_same set.each { |v| yielded << v }, set
	assert_equal yielded.sort, [1, 2]
end

test "#subset?, #superset?, #intersect? and #disjoint?" do
	set = Literal::Set(Integer).new(1, 2)

	assert set.subset?(Literal::Set(Integer).new(1, 2, 3))
	assert set.subset?(::Set[1, 2, 3])
	assert set.superset?(::Set[1])
	assert set.intersect?(Literal::Set(Integer).new(2, 3))
	assert set.intersect?([2])
	assert set.disjoint?(::Set[3])

	assert_raises(ArgumentError) { set.subset?([1, 2, 3]) }
end

test "#to_a and #to_set return detached plain copies" do
	set = Literal::Set(Integer).new(1, 2)

	plain_set = set.to_set
	refute_same plain_set, set.__value__

	plain_set << 3
	assert_equal set.to_a.sort, [1, 2]
end

test "#inspect" do
	assert_equal Literal::Set(Integer).new(1).inspect, "Literal::Set(Integer){1}"
end

# Type-preserving copies

test "#| and #^ check members at the boundary" do
	set = Literal::Set(Integer).new(1, 2)

	assert_literal_set set | Literal::Set(Integer).new(3), type: Integer, members: [1, 2, 3]
	assert_literal_set set | [2, 3], type: Integer, members: [1, 2, 3]
	assert_literal_set set ^ ::Set[2, 3], type: Integer, members: [1, 3]

	assert_raises(Literal::TypeError) { set | ["a"] }
	assert_raises(Literal::TypeError) { set ^ ["a"] }
	assert_raises(Literal::TypeError) { set | Literal::Set(String).new("a") }
end

test "#& and #- accept any members because the result is a subset" do
	set = Literal::Set(Integer).new(1, 2)

	assert_literal_set set & [2, "x"], type: Integer, members: [2]
	assert_literal_set set - Literal::Set(Numeric).new(1), type: Integer, members: [2]
	assert_literal_set set - ::Set[2], type: Integer, members: [1]
end

test "combining with a non-collection raises" do
	set = Literal::Set(Integer).new(1)

	assert_raises(ArgumentError) { set | 1 }
	assert_raises(ArgumentError) { set & "nope" }
	assert_raises(ArgumentError) { set.merge(:nope) }
end

test "#select and #reject return typed copies" do
	set = Literal::Set(Integer).new(1, 2, 3)

	selected = set.select(&:even?)
	rejected = set.reject(&:even?)

	assert_literal_set selected, type: Integer, members: [2]
	assert_literal_set rejected, type: Integer, members: [1, 3]
	refute_same selected.__value__, set.__value__
	assert_equal set.size, 3
end

test "#sort and #sort_by return typed literal arrays" do
	set = Literal::Set(Integer).new(3, 1, 2)

	sorted = set.sort

	assert Literal::Array(Integer) === sorted
	assert_equal sorted.to_a, [1, 2, 3]

	sorted_by = set.sort_by { |i| i * -1 }

	assert Literal::Array(Integer) === sorted_by
	assert_equal sorted_by.to_a, [3, 2, 1]
end

# Type-changing transforms

test "#map requires an explicit type" do
	set = Literal::Set(Integer).new(1, 2, 3)

	mapped = set.map(String, &:to_s)

	assert_literal_set mapped, type: String, members: ["1", "2", "3"]

	assert_raises(Literal::TypeError) do
		set.map(Integer, &:to_s)
	end
end

test "#map checks against the target type even when the transform is known" do
	set = Literal::Set(Integer).new(1, 2)

	assert_raises(Literal::TypeError) do
		set.map(String, &:succ)
	end

	assert_literal_set set.map(Integer, &:succ), type: Integer, members: [2, 3]
end

test "#map deduplicates" do
	set = Literal::Set(Integer).new(1, 2, 3)

	assert_literal_set set.map(Integer) { |i| i % 2 }, type: Integer, members: [0, 1]
end

# Checked mutations

test "#add checks the member and returns self" do
	set = Literal::Set(Integer).new(1)

	assert_same set.add(2), set
	assert_same set.add(2), set
	assert_equal set.size, 2

	assert_raises(Literal::TypeError) { set.add("3") }
	assert_literal_set set, type: Integer, members: [1, 2]
end

test "#<< is an alias for #add" do
	set = Literal::Set(Integer).new

	assert_same set << 1 << 2, set
	assert_literal_set set, type: Integer, members: [1, 2]

	assert_raises(Literal::TypeError) { set << "3" }
end

test "#merge checks every source before mutating" do
	set = Literal::Set(Numeric).new(1)

	assert_same set.merge(Literal::Set(Integer).new(2), [3.5]), set
	assert_literal_set set, type: Numeric, members: [1, 2, 3.5]

	assert_raises(Literal::TypeError) { set.merge(["a"]) }
	assert_raises(Literal::TypeError) { set.merge(Literal::Set(String).new("a")) }
	assert_literal_set set, type: Numeric, members: [1, 2, 3.5]
end

test "#replace swaps contents without sharing storage" do
	set = Literal::Set(Integer).new(1)
	other = Literal::Set(Integer).new(2)

	assert_same set.replace(other), set
	assert_equal set, other
	refute_same set.__value__, other.__value__

	assert_same set.replace([3]), set
	assert_literal_set set, type: Integer, members: [3]

	assert_raises(Literal::TypeError) { set.replace(["a"]) }
end

test "#map! rechecks against the member type" do
	set = Literal::Set(Integer).new(1, 2)

	assert_same set.map!(&:succ), set
	assert_literal_set set, type: Integer, members: [2, 3]

	assert_raises(Literal::TypeError) { set.map!(&:to_s) }
	assert_literal_set set, type: Integer, members: [2, 3]
end

test "#delete, #subtract and #clear return self" do
	set = Literal::Set(Integer).new(1, 2, 3, 4)

	assert_same set.delete(1), set
	assert_same set.delete(1), set
	assert_same set.subtract([2, "x"]), set
	assert_literal_set set, type: Integer, members: [3, 4]

	assert_same set.clear, set
	assert set.empty?
end

test "#select! and #reject! return self" do
	set = Literal::Set(Integer).new(1, 2, 3)

	assert_same set.select! { |i| i > 1 }, set
	assert_literal_set set, type: Integer, members: [2, 3]

	assert_same set.reject! { |i| i > 2 }, set
	assert_literal_set set, type: Integer, members: [2]
end

# Copying and freezing

test "#dup does not share storage with the original" do
	set = Literal::Set(Integer).new(1)
	copy = set.dup

	copy.add(2)

	assert_equal copy.size, 2
	assert_equal set.size, 1
end

test "#freeze freezes the underlying storage" do
	set = Literal::Set(Integer).new(1).freeze

	assert set.frozen?
	assert_raises(FrozenError) { set.add(2) }
	assert_raises(FrozenError) { set.clear }
end

test "#clone of a frozen set is frozen" do
	set = Literal::Set(Integer).new(1).freeze
	copy = set.clone

	assert copy.frozen?
	assert_raises(FrozenError) { copy.add(2) }
end

# Narrowing and widening

test "#narrow returns a detached set with the narrower type" do
	set = Literal::Set(Numeric).new(1, 2)

	narrowed = set.narrow(Integer)

	assert_literal_set narrowed, type: Integer, members: [1, 2]
	refute_same narrowed.__value__, set.__value__

	assert_raises(Literal::TypeError) { Literal::Set(Numeric).new(1.5).narrow(Integer) }
	assert_raises(ArgumentError) { set.narrow(String) }
end

test "#widen returns a detached set with the wider type" do
	set = Literal::Set(Integer).new(1)

	widened = set.widen(Numeric)

	assert_literal_set widened, type: Numeric, members: [1]
	refute_same widened.__value__, set.__value__

	widened.add(1.5)
	assert_equal set.size, 1

	assert_raises(ArgumentError) { set.widen(String) }
end

# Enumerable

test "supported Enumerable methods work" do
	set = Literal::Set(Integer).new(1, 2, 3)

	assert set.all? { |i| i > 0 }
	assert set.any?(&:even?)
	assert set.none? { |i| i > 3 }
	assert set.one?(&:even?)
	assert_equal set.find(&:even?), 2
	assert_equal set.reduce(:+), 6
	assert Enumerable === set
end

test "unsupported Enumerable methods and aliases are removed" do
	set = Literal::Set(Integer).new(1)

	%i[
		group_by
		partition
		zip
		tally
		minmax
		entries
		to_h
		lazy
		grep
		detect
		inject
		collect
		filter
		member?
		flat_map
		filter_map
		add?
		union
		intersection
		difference
		length
		count
	].each do |method|
		refute set.respond_to?(method)
	end
end

test "block-transform methods require a block" do
	set = Literal::Set(Integer).new(1)

	assert_raises(ArgumentError) { set.map(String) }
	assert_raises(ArgumentError) { set.select }
	assert_raises(ArgumentError) { set.reject }
	assert_raises(ArgumentError) { set.sort_by }
end
