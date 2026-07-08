# frozen_string_literal: true

include Literal::Types

# Asserts the two types are equivalent — each a subtype of the other.
def assert_type_equal(actual, expected)
	assert Literal.subtype?(actual, expected)
	assert Literal.subtype?(expected, actual)
end

# Asserts `array` is a Literal::Array with exactly the given type and values.
def assert_literal_array(array, type:, values:)
	assert Literal::Array === array
	assert_type_equal array.__type__, type
	assert_equal array.to_a, values
end

# Asserts the two literal arrays don't share underlying storage.
def refute_shared_storage(a, b)
	refute_same a.__value__, b.__value__
end

# Generic

test "Generic#new creates a checked literal array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array, type: Integer, values: [1, 2, 3]
end

test "Generic#new raises when a value doesn't match the type" do
	assert_raises(Literal::TypeError) do
		Literal::Array(String).new("a", 1)
	end
end

test "Generic#[] is equivalent to Generic#new" do
	assert_equal Literal::Array(Integer)[1, 2, 3], Literal::Array(Integer).new(1, 2, 3)
end

test "Generic#coerce converts a plain array" do
	array = Literal::Array(String).coerce(["Joel", "Stephen"])

	assert_literal_array array, type: String, values: ["Joel", "Stephen"]
end

test "Generic#coerce raises when a plain array has invalid elements" do
	assert_raises(Literal::TypeError) do
		Literal::Array(Integer).coerce(["Joel"])
	end
end

test "Generic#coerce passes a matching literal array through unchanged" do
	array = Literal::Array(Integer).new(1, 2)

	assert_same Literal::Array(Integer).coerce(array), array
end

test "Generic#coerce passes a subtype literal array through unchanged" do
	array = Literal::Array(Integer).new(1, 2)

	assert_same Literal::Array(Numeric).coerce(array), array
end

test "Generic#coerce returns nil for uncoercible values" do
	assert_equal Literal::Array(Integer).coerce("nope"), nil
	assert_equal Literal::Array(Integer).coerce(Literal::Array(String).new("a")), nil
end

test "Generic#to_proc coerces" do
	mapped = [["Joel"]].map(&Literal::Array(String))

	assert_equal mapped, [Literal::Array(String).new("Joel")]
end

test "Generic#=== matches covariantly" do
	assert Literal::Array(Integer) === Literal::Array(Integer).new(1)
	assert Literal::Array(Numeric) === Literal::Array(Integer).new(1)
	assert Literal::Array(_Nilable(String)) === Literal::Array(String).new("a")

	refute Literal::Array(Integer) === Literal::Array(Numeric).new(1)
	refute Literal::Array(String) === Literal::Array(Integer).new(1)
end

test "Generic#=== matches nested literal arrays" do
	nested = Literal::Array(Literal::Array(Integer)).new(
		Literal::Array(Integer).new(1),
	)

	assert Literal::Array(Literal::Array(Numeric)) === nested
	refute Literal::Array(Literal::Array(String)) === nested
end

test "Generic#== compares element types" do
	assert_equal Literal::Array(Integer), Literal::Array(Integer)
	assert_equal Literal::Array(Literal::Array(Integer)), Literal::Array(Literal::Array(Integer))
	refute_equal Literal::Array(Integer), Literal::Array(String)
end

test "Generic subtyping is covariant" do
	assert Literal.subtype?(Literal::Array(Integer), Literal::Array(Numeric))
	refute Literal.subtype?(Literal::Array(Numeric), Literal::Array(Integer))
end

test "Generic#inspect" do
	assert_equal Literal::Array(Integer).inspect, "Literal::Array(Integer)"
end

# Distinctness from plain arrays

test "a literal array is not a plain array and vice versa" do
	array = Literal::Array(Integer).new(1, 2, 3)

	refute Literal::Array(Integer) === [1, 2, 3]
	refute _Array(Integer) === array
	refute ::Array === array
end

test "literal array types and plain array types are never subtypes of each other" do
	refute Literal.subtype?(Literal::Array(Integer), _Array(Integer))
	refute Literal.subtype?(_Array(Integer), Literal::Array(Integer))
end

test "#to_ary converts to a detached plain array, enabling splats and destructuring" do
	array = Literal::Array(Integer).new(1, 2, 3)

	plain = array.to_ary
	assert_equal plain, [1, 2, 3]
	refute_same plain, array.__value__

	assert_equal [*array], [1, 2, 3]

	a, b, c = array
	assert_equal [a, b, c], [1, 2, 3]
end

test "combining with a plain array type checks at the boundary" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array + [4], type: Integer, values: [1, 2, 3, 4]
	assert_literal_array array | [3, 4], type: Integer, values: [1, 2, 3, 4]
	assert_literal_array array - [1], type: Integer, values: [2, 3]
	assert_literal_array array & [2, 4], type: Integer, values: [2]

	assert_raises(Literal::TypeError) { array + ["a"] }
	assert_raises(Literal::TypeError) { array | ["a"] }
end

test "combining with a non-array raises" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(ArgumentError) { array + :nope }
	assert_raises(ArgumentError) { array - 1 }
	assert_raises(ArgumentError) { array & nil }
	assert_raises(ArgumentError) { array | "nope" }
	assert_raises(ArgumentError) { array.concat(1) }
	assert_raises(ArgumentError) { array.replace("nope") }
end

# Construction

test "#initialize copies the input, so the caller's reference is harmless" do
	input = [1, 2]
	array = Literal::Array(Integer).coerce(input)

	input << "3"

	assert_equal array.to_a, [1, 2]
end

test "#initialize checks the whole array" do
	assert_raises(Literal::TypeError) do
		Literal::Array.new([1, "2"], type: Integer)
	end
end

test "an empty literal array is valid" do
	assert_literal_array Literal::Array(Integer).new, type: Integer, values: []
end

# Equality

test "#== is structural" do
	assert_equal Literal::Array(Integer).new(1, 2), Literal::Array(Integer).new(1, 2)
	refute_equal Literal::Array(Integer).new(1, 2), Literal::Array(Integer).new(2, 1)

	# Types are not part of `==` — empty arrays of different types are equal.
	assert_equal Literal::Array(Integer).new, Literal::Array(String).new
end

test "#== never matches a plain array" do
	refute_equal Literal::Array(Integer).new(1, 2), [1, 2]
end

test "#eql? requires the same type" do
	a = Literal::Array(Integer).new(1, 2)
	b = Literal::Array(Integer).new(1, 2)

	assert a.eql?(b)
	assert_equal a.hash, b.hash

	refute Literal::Array(Integer).new.eql?(Literal::Array(String).new)
end

test "#<=> compares against literal and plain arrays" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal (array <=> Literal::Array(Integer).new(1, 2, 4)), -1
	assert_equal (array <=> Literal::Array(Integer).new(1, 2)), 1
	assert_equal (array <=> Literal::Array(Integer).new(1, 2, 3)), 0
	assert_equal (array <=> [1, 2, 4]), -1
	assert_equal (array <=> "nope"), nil
end

# Reads

test "#[] with an index returns the element" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array[0], 1
	assert_equal array[-1], 3
	assert_equal array[3], nil
end

test "#[] with a range returns a typed sub-array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array[0..1], type: Integer, values: [1, 2]
	assert_literal_array array[2..], type: Integer, values: [3]
	assert_equal array[5..], nil
end

test "#[] with a start and length returns a typed sub-array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array[1, 2], type: Integer, values: [2, 3]
end

test "#fetch" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.fetch(0), 1
	assert_equal array.fetch(4, :missing), :missing
	assert_equal array.fetch(4) { |i| i * 2 }, 8
	assert_raises(IndexError) { array.fetch(3) }
end

test "#first and #last return elements without an argument" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.first, 1
	assert_equal array.last, 3
	assert_equal Literal::Array(Integer).new.first, nil
end

test "#first and #last return typed arrays with an argument" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array.first(2), type: Integer, values: [1, 2]
	assert_literal_array array.last(2), type: Integer, values: [2, 3]
end

test "#each yields elements and returns self" do
	array = Literal::Array(Integer).new(1, 2, 3)
	yielded = []

	return_value = array.each { |i| yielded << i }

	assert_same return_value, array
	assert_equal yielded, [1, 2, 3]
end

test "#each without a block returns an enumerator over elements" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.each.next, 1
end

test "#size, #empty?, #include?, #count, #index and #dig" do
	array = Literal::Array(Integer).new(1, 2, 2)

	assert_equal array.size, 3
	refute array.empty?
	assert Literal::Array(Integer).new.empty?
	assert array.include?(2)
	refute array.include?(4)
	assert_equal array.count(2), 2
	assert_equal array.index(2), 1
	assert_equal array.index { |i| i > 1 }, 1

	nested = Literal::Array(Literal::Array(Integer)).new(Literal::Array(Integer).new(1))
	assert_equal nested.dig(0, 0), 1
end

test "#join and #sum" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.join(", "), "1, 2, 3"
	assert_equal array.sum, 6
end

test "#min and #max return elements without an argument" do
	array = Literal::Array(Integer).new(3, 1, 2)

	assert_equal array.min, 1
	assert_equal array.max, 3
end

test "#min and #max return typed arrays with an argument" do
	array = Literal::Array(Integer).new(3, 1, 2)

	assert_literal_array array.min(2), type: Integer, values: [1, 2]
	assert_literal_array array.max(2), type: Integer, values: [3, 2]
end

test "#min_by and #max_by" do
	array = Literal::Array(String).new("bb", "a", "ccc")

	assert_equal array.min_by(&:length), "a"
	assert_equal array.max_by(&:length), "ccc"
	assert_literal_array array.min_by(2, &:length), type: String, values: ["a", "bb"]
end

test "#sample" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.sample(random: Random.new(42)), array.sample(random: Random.new(42))
	assert_literal_array array.sample(3, random: Random.new(42)), type: Integer, values: array.sample(3, random: Random.new(42)).to_a
end

test "#to_a returns a detached plain array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	plain = array.to_a

	assert_equal plain, [1, 2, 3]
	refute_same plain, array.__value__

	plain << 4
	assert_equal array.to_a, [1, 2, 3]
end

test "#inspect and #to_s" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.inspect, "Literal::Array(Integer)[1, 2, 3]"
	assert_equal array.to_s, "Literal::Array(Integer)[1, 2, 3]"
end

# Type-preserving copies

test "#+ concatenates compatible literal arrays" do
	array = Literal::Array(Numeric).new(1, 2)
	other = Literal::Array(Integer).new(3)

	result = array + other

	assert_literal_array result, type: Numeric, values: [1, 2, 3]
	refute_shared_storage result, array
	refute_shared_storage result, other
end

test "#+ raises for an incompatible literal array" do
	assert_raises(Literal::TypeError) do
		Literal::Array(Integer).new(1) + Literal::Array(String).new("a")
	end
end

test "#- and #& accept literal arrays of any type" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array - Literal::Array(Numeric).new(1), type: Integer, values: [2, 3]
	assert_literal_array array & Literal::Array(Numeric).new(2, 4), type: Integer, values: [2]
end

test "#| requires a compatible literal array" do
	array = Literal::Array(Integer).new(1, 2)

	result = array | Literal::Array(Integer).new(2, 3)

	assert_literal_array result, type: Integer, values: [1, 2, 3]

	assert_raises(Literal::TypeError) do
		array | Literal::Array(String).new("a")
	end
end

test "#* repeats the array" do
	array = Literal::Array(Integer).new(1, 2)

	assert_literal_array array * 2, type: Integer, values: [1, 2, 1, 2]
end

test "#* does not join with a string" do
	assert_raises(ArgumentError) do
		Literal::Array(Integer).new(1, 2) * ","
	end
end

test "copying transforms preserve the type and don't share storage" do
	array = Literal::Array(Integer).new(3, 1, 2, 2)

	{
		sort: [1, 2, 2, 3],
		reverse: [2, 2, 1, 3],
		uniq: [3, 1, 2],
		rotate: [1, 2, 2, 3],
	}.each do |method, expected|
		result = array.public_send(method)

		assert_literal_array result, type: Integer, values: expected
		refute_shared_storage result, array
	end

	assert_equal array.to_a, [3, 1, 2, 2]
end

test "#select and #reject return typed copies" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array.select(&:even?), type: Integer, values: [2]
	assert_literal_array array.reject(&:even?), type: Integer, values: [1, 3]
	assert_equal array.to_a, [1, 2, 3]
end

test "#sort_by returns a typed copy" do
	array = Literal::Array(String).new("bb", "a")

	assert_literal_array array.sort_by(&:length), type: String, values: ["a", "bb"]
end

test "#take, #drop, #take_while and #drop_while return typed copies" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array.take(2), type: Integer, values: [1, 2]
	assert_literal_array array.drop(2), type: Integer, values: [3]
	assert_literal_array array.take_while { |i| i < 3 }, type: Integer, values: [1, 2]
	assert_literal_array array.drop_while { |i| i < 3 }, type: Integer, values: [3]
end

test "#shuffle returns a typed copy" do
	array = Literal::Array(Integer).new(1, 2, 3, 4, 5)

	result = array.shuffle(random: Random.new(42))

	assert_type_equal result.__type__, Integer
	assert_equal result.to_a.sort, [1, 2, 3, 4, 5]
	refute_shared_storage result, array
end

test "#compact narrows a nilable type" do
	array = Literal::Array(_Nilable(Integer)).new(1, nil, 2)

	result = array.compact

	assert_literal_array result, type: Integer, values: [1, 2]
	assert_equal array.to_a, [1, nil, 2]
end

test "#compact narrows a union containing nil" do
	array = Literal::Array(_Union(Integer, String, nil)).new(1, "a", nil)

	result = array.compact

	assert_literal_array result, type: _Union(Integer, String), values: [1, "a"]
end

test "#compact on a non-nilable type returns a detached copy" do
	array = Literal::Array(Integer).new(1, 2)

	result = array.compact

	assert_literal_array result, type: Integer, values: [1, 2]
	refute_shared_storage result, array
end

# Type-changing transforms

test "#map requires an explicit type" do
	array = Literal::Array(Integer).new(1, 2, 3)

	mapped = array.map(String, &:to_s)

	assert_literal_array mapped, type: String, values: ["1", "2", "3"]
end

test "#map raises when results don't match the target type" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.map(Integer, &:to_s)
	end
end

test "#map checks against the target type even when the transform is known" do
	array = Literal::Array(Integer).new(1, 2, 3)

	# :succ is a known Integer -> Integer transform, but the target type is
	# String, so the fast path must not be taken.
	assert_raises(Literal::TypeError) do
		array.map(String, &:succ)
	end
end

test "#map uses the known-transform fast path when it is sound" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_literal_array array.map(Integer, &:succ), type: Integer, values: [2, 3, 4]
	assert_literal_array array.map(Numeric, &:succ), type: Numeric, values: [2, 3, 4]
end

test "#filter_map" do
	array = Literal::Array(Integer).new(1, 2, 3)

	result = array.filter_map(String) { |i| i.to_s if i.odd? }

	assert_literal_array result, type: String, values: ["1", "3"]

	assert_raises(Literal::TypeError) do
		array.filter_map(Integer) { |i| i.to_s if i.odd? }
	end
end

test "#flat_map splices literal arrays, plain arrays and single values" do
	array = Literal::Array(Integer).new(1, 2, 3)

	from_literal = array.flat_map(Integer) { |i| Literal::Array(Integer).new(i, i) }
	from_plain = array.flat_map(Integer) { |i| [i, i] }
	from_scalar = array.flat_map(Integer) { |i| i * 10 }

	assert_literal_array from_literal, type: Integer, values: [1, 1, 2, 2, 3, 3]
	assert_literal_array from_plain, type: Integer, values: [1, 1, 2, 2, 3, 3]
	assert_literal_array from_scalar, type: Integer, values: [10, 20, 30]

	assert_raises(Literal::TypeError) do
		array.flat_map(String) { |i| [i] }
	end
end

# Tuple-producing methods

test "#zip produces typed tuples" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1, 2)

	result = a.zip(b)

	assert_type_equal result.__type__, Literal::Tuple(String, Integer)
	assert_equal result.size, 2
	assert_equal result[0], Literal::Tuple(String, Integer).new("a", 1)
	assert_equal result[1].to_a, ["b", 2]
end

test "#zip types plain arrays as _Any?" do
	a = Literal::Array(String).new("a", "b")

	result = a.zip([1, 2], [:x, :y])

	assert_type_equal result.__type__, Literal::Tuple(String, _Any?, _Any?)
	assert_equal result[0].to_a, ["a", 1, :x]
end

test "#zip truncates longer arrays to our length" do
	a = Literal::Array(String).new("a")

	result = a.zip(Literal::Array(Integer).new(1, 2))

	assert_equal result.size, 1
	assert_equal result[0].to_a, ["a", 1]
end

test "#zip pads shorter arrays with nil when their type allows it" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(_Nilable(Integer)).new(1)

	result = a.zip(b, [:x])

	assert_type_equal result.__type__, Literal::Tuple(String, _Nilable(Integer), _Any?)
	assert_equal result[1].to_a, ["b", nil, nil]
end

test "#zip raises when a shorter array's type is not nilable" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1)

	assert_raises(ArgumentError) { a.zip(b) }
end

test "#zip with a block yields tuples and returns nil" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1, 2)

	yielded = []

	assert_equal a.zip(b) { |tuple| yielded << tuple }, nil
	assert_equal yielded, [
		Literal::Tuple(String, Integer).new("a", 1),
		Literal::Tuple(String, Integer).new("b", 2),
	]
end

test "#zip with a non-array raises" do
	assert_raises(ArgumentError) { Literal::Array(String).new("a").zip(1) }
end

test "#product produces typed tuples of every combination" do
	a = Literal::Array(Integer).new(1, 2)
	b = Literal::Array(String).new("a", "b")

	result = a.product(b)

	assert_type_equal result.__type__, Literal::Tuple(Integer, String)
	assert_equal result.size, 4
	assert_equal result[0], Literal::Tuple(Integer, String).new(1, "a")
	assert_equal result.to_a.map(&:to_a), [[1, "a"], [1, "b"], [2, "a"], [2, "b"]]
end

test "#product with a plain array and a block yields tuples and returns self" do
	a = Literal::Array(Integer).new(1, 2)
	yielded = []

	assert_same a.product(["x"]) { |tuple| yielded << tuple.to_a }, a
	assert_equal yielded, [[1, "x"], [2, "x"]]
end

test "#transpose of an array of tuples returns a tuple of typed arrays" do
	array = Literal::Array(Literal::Tuple(Integer, String)).new(
		Literal::Tuple(Integer, String).new(1, "a"),
		Literal::Tuple(Integer, String).new(2, "b"),
	)

	result = array.transpose

	assert Literal::Tuple === result
	assert_equal result.size, 2

	assert Literal::Array(Integer) === result[0]
	assert_equal result[0].to_a, [1, 2]

	assert Literal::Array(String) === result[1]
	assert_equal result[1].to_a, ["a", "b"]
end

test "#transpose of an empty array of tuples returns empty typed arrays" do
	array = Literal::Array(Literal::Tuple(Integer, String)).new

	result = array.transpose

	assert_equal result.size, 2
	assert result[0].empty?
	assert Literal::Array(String) === result[1]
end

test "#transpose of an array of arrays swaps rows and columns" do
	array = Literal::Array(Literal::Array(Integer)).new(
		Literal::Array(Integer).new(1, 2),
		Literal::Array(Integer).new(3, 4),
	)

	result = array.transpose

	assert Literal::Array(Literal::Array(Integer)) === result
	assert_equal result[0].to_a, [1, 3]
	assert_equal result[1].to_a, [2, 4]
end

test "#transpose raises on ragged rows" do
	array = Literal::Array(Literal::Array(Integer)).new(
		Literal::Array(Integer).new(1, 2),
		Literal::Array(Integer).new(3),
	)

	assert_raises(IndexError) { array.transpose }
end

test "#transpose raises when the element type is not a tuple or array" do
	assert_raises(ArgumentError) { Literal::Array(Integer).new(1).transpose }
end

test "#partition returns a tuple of two typed arrays" do
	array = Literal::Array(Integer).new(1, 2, 3, 4)

	evens, odds = array.partition(&:even?)

	assert Literal::Array(Integer) === evens
	assert Literal::Array(Integer) === odds
	assert_equal evens.to_a, [2, 4]
	assert_equal odds.to_a, [1, 3]
end

test "#minmax and #minmax_by return typed tuples" do
	array = Literal::Array(Integer).new(3, 1, 2)

	result = array.minmax

	assert Literal::Tuple(Integer, Integer) === result
	assert_equal result.to_a, [1, 3]

	assert_equal array.minmax_by { |i| i * -1 }.to_a, [3, 1]
end

test "#minmax on an empty array requires a nilable type" do
	assert_raises(ArgumentError) { Literal::Array(Integer).new.minmax }
	assert_equal Literal::Array(_Nilable(Integer)).new.minmax.to_a, [nil, nil]
end

# Checked mutations

test "#<< appends a checked value and returns self" do
	array = Literal::Array(Integer).new(1)

	assert_same array << 2, array
	assert_equal array.to_a, [1, 2]

	assert_raises(Literal::TypeError) { array << "3" }
	assert_equal array.to_a, [1, 2]
end

test "#push and #unshift check every value before mutating" do
	array = Literal::Array(Integer).new(2)

	assert_same array.push(3, 4), array
	assert_same array.unshift(0, 1), array
	assert_equal array.to_a, [0, 1, 2, 3, 4]

	assert_raises(Literal::TypeError) { array.push(5, "6") }
	assert_raises(Literal::TypeError) { array.unshift("-1", 0) }
	assert_equal array.to_a, [0, 1, 2, 3, 4]
end

test "#[]= checks the value" do
	array = Literal::Array(Integer).new(1, 2, 3)

	array[0] = 5

	assert_equal array.to_a, [5, 2, 3]
	assert_raises(Literal::TypeError) { array[0] = "5" }
end

test "#[]= can't pad a non-nilable array with nils" do
	array = Literal::Array(Integer).new(1)

	array[1] = 2
	assert_equal array.to_a, [1, 2]

	assert_raises(Literal::TypeError) { array[5] = 3 }
	assert_equal array.to_a, [1, 2]
end

test "#[]= pads a nilable array with nils" do
	array = Literal::Array(_Nilable(Integer)).new(1)

	array[3] = 2

	assert_equal array.to_a, [1, nil, nil, 2]
end

test "#insert checks values and padding" do
	array = Literal::Array(Integer).new(1, 4)

	assert_same array.insert(1, 2, 3), array
	assert_equal array.to_a, [1, 2, 3, 4]

	assert_raises(Literal::TypeError) { array.insert(1, "2") }
	assert_raises(Literal::TypeError) { array.insert(10, 5) }
	assert_equal array.to_a, [1, 2, 3, 4]
end

test "#concat checks compatibility" do
	array = Literal::Array(Numeric).new(1)

	assert_same array.concat(Literal::Array(Integer).new(2), Literal::Array(Float).new(3.0)), array
	assert_equal array.to_a, [1, 2, 3.0]

	assert_same array.concat([4], [5.0]), array
	assert_equal array.to_a, [1, 2, 3.0, 4, 5.0]

	assert_raises(Literal::TypeError) do
		array.concat(Literal::Array(String).new("a"))
	end

	assert_raises(Literal::TypeError) do
		array.concat(["a"])
	end

	assert_equal array.to_a, [1, 2, 3.0, 4, 5.0]
end

test "#replace swaps contents without sharing storage" do
	array = Literal::Array(Integer).new(1, 2)
	other = Literal::Array(Integer).new(3, 4)

	assert_same array.replace(other), array
	assert_equal array.to_a, [3, 4]
	refute_shared_storage array, other

	plain = [5, 6]
	assert_same array.replace(plain), array
	assert_equal array.to_a, [5, 6]
	refute_same array.__value__, plain

	assert_raises(Literal::TypeError) do
		array.replace(Literal::Array(String).new("a"))
	end

	assert_raises(Literal::TypeError) do
		array.replace(["a"])
	end

	assert_equal array.to_a, [5, 6]
end

test "#map! rechecks against the element type" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_same array.map!(&:succ), array
	assert_equal array.to_a, [2, 3, 4]

	assert_raises(Literal::TypeError) { array.map!(&:to_s) }
	assert_equal array.to_a, [2, 3, 4]
end

test "#delete and #delete_at return the removed element" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.delete(2), 2
	assert_equal array.delete_at(0), 1
	assert_equal array.to_a, [3]
end

test "#pop and #shift return elements without an argument" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.pop, 3
	assert_equal array.shift, 1
	assert_equal array.to_a, [2]
end

test "#pop and #shift return typed arrays with an argument" do
	array = Literal::Array(Integer).new(1, 2, 3, 4)

	assert_literal_array array.pop(2), type: Integer, values: [3, 4]
	assert_literal_array array.shift(1), type: Integer, values: [1]
	assert_equal array.to_a, [2]
end

test "in-place transforms always return self" do
	array = Literal::Array(Integer).new(3, 1, 2, 2)

	assert_same array.sort!, array
	assert_equal array.to_a, [1, 2, 2, 3]

	assert_same array.uniq!, array
	assert_equal array.to_a, [1, 2, 3]

	# Even when nothing changes, unlike Ruby's Array which returns nil.
	assert_same array.uniq!, array
	assert_same array.compact!, array

	assert_same array.reverse!, array
	assert_equal array.to_a, [3, 2, 1]

	assert_same array.rotate!, array
	assert_equal array.to_a, [2, 1, 3]

	assert_same array.select! { |i| i > 1 }, array
	assert_equal array.to_a, [2, 3]

	assert_same array.reject! { |i| i > 2 }, array
	assert_equal array.to_a, [2]

	assert_same array.clear, array
	assert array.empty?
end

test "#sort_by! and #shuffle! mutate in place and return self" do
	array = Literal::Array(String).new("bb", "a")

	assert_same array.sort_by!(&:length), array
	assert_equal array.to_a, ["a", "bb"]

	numbers = Literal::Array(Integer).new(1, 2, 3, 4, 5)
	assert_same numbers.shuffle!(random: Random.new(42)), numbers
	assert_equal numbers.to_a.sort, [1, 2, 3, 4, 5]
end

test "#compact! removes nils but keeps the type" do
	array = Literal::Array(_Nilable(Integer)).new(1, nil, 2)

	assert_same array.compact!, array
	assert_equal array.to_a, [1, 2]
	assert_type_equal array.__type__, _Nilable(Integer)
end

# Copying

test "#dup does not share storage with the original" do
	array = Literal::Array(Integer).new(1, 2)
	copy = array.dup

	copy << 3

	assert_equal copy.to_a, [1, 2, 3]
	assert_equal array.to_a, [1, 2]
end

test "#clone of a frozen array is frozen" do
	array = Literal::Array(Integer).new(1, 2).freeze
	copy = array.clone

	assert copy.frozen?
	assert_raises(FrozenError) { copy << 3 }
end

# Freezing

test "#freeze freezes the underlying storage" do
	array = Literal::Array(Integer).new(1, 2).freeze

	assert array.frozen?
	assert_raises(FrozenError) { array << 3 }
	assert_raises(FrozenError) { array.map!(&:succ) }
	assert_raises(FrozenError) { array.clear }
end

# Narrowing

test "#narrow returns a detached array with the narrower type" do
	array = Literal::Array(Numeric).new(1, 2, 3)

	narrowed = array.narrow(Integer)

	assert_literal_array narrowed, type: Integer, values: [1, 2, 3]
	refute_shared_storage narrowed, array
end

test "#narrow raises when a value doesn't match the narrower type" do
	array = Literal::Array(Numeric).new(1, 2.5)

	assert_raises(Literal::TypeError) do
		array.narrow(Integer)
	end
end

test "#narrow raises when the type is not a subtype" do
	array = Literal::Array(Integer).new(1)

	assert_raises(ArgumentError) do
		array.narrow(String)
	end
end

# Widening

test "#widen returns a detached array with the wider type" do
	array = Literal::Array(Integer).new(1, 2)

	widened = array.widen(Numeric)

	assert_literal_array widened, type: Numeric, values: [1, 2]
	refute_shared_storage widened, array

	widened << 1.5
	assert_equal widened.to_a, [1, 2, 1.5]
	assert_equal array.to_a, [1, 2]
end

test "#widen raises when the type is not a supertype" do
	array = Literal::Array(Integer).new(1)

	assert_raises(ArgumentError) do
		array.widen(String)
	end
end

# Enumerable

test "supported Enumerable methods work" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert array.all? { |i| i > 0 }
	assert array.any?(&:even?)
	assert array.none? { |i| i > 3 }
	assert array.one?(&:even?)
	assert_equal array.find(&:even?), 2
	assert_equal array.reduce(:+), 6
	assert_equal array.each_with_object([]) { |i, acc| acc << i }, [1, 2, 3]
	assert_equal array.each_with_index.to_a, [[1, 0], [2, 1], [3, 2]]
	assert Enumerable === array
end

test "unsupported Enumerable methods are removed" do
	array = Literal::Array(Integer).new(1, 2, 3)

	%i[
		group_by
		tally
		each_slice
		each_cons
		chunk_while
		slice_when
		entries
		to_h
		lazy
		grep
		detect
		inject
		collect
		filter
		member?
		find_all
	].each do |method|
		refute array.respond_to?(method)
	end

	assert_raises(NoMethodError) { array.group_by(&:even?) }
end

test "aliases are not provided" do
	array = Literal::Array(Integer).new(1, 2, 3)

	refute array.respond_to?(:length)
	refute array.respond_to?(:append)
	refute array.respond_to?(:prepend)
	refute array.respond_to?(:collect!)
	refute array.respond_to?(:keep_if)
	refute array.respond_to?(:delete_if)
end

test "block-transform methods require a block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(ArgumentError) { array.map(String) }
	assert_raises(ArgumentError) { array.select }
	assert_raises(ArgumentError) { array.reject }
	assert_raises(ArgumentError) { array.sort_by }
	assert_raises(ArgumentError) { array.take_while }
	assert_raises(ArgumentError) { array.drop_while }
	assert_raises(ArgumentError) { array.partition }
	assert_raises(ArgumentError) { array.minmax_by }
end
