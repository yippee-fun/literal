# frozen_string_literal: true

include Literal::Types

test "coerce" do
	original = ["Joel", "Stephen"]
	coerced = Literal::Array(String).coerce(original)

	assert_equal coerced, Literal::Array(String).new(
		"Joel", "Stephen"
	)
end

test "coerce with invalid values" do
	original = ["Joel", "Stephen"]

	assert_raises(Literal::TypeError) do
		Literal::Array(Integer).coerce(original)
	end
end

test "to_proc" do
	mapped = [
		["Joel", "Stephen"],
	].map(&Literal::Array(String))

	assert_equal mapped, [
		Literal::Array(String).new(
			"Joel", "Stephen"
		),
	]
end

test "===" do
	assert Literal::Array(_Boolean) === Literal::Array(true).new(true)
	assert Literal::Array(Object) === Literal::Array(Integer).new(1)
	assert Literal::Array(Numeric) === Literal::Array(Integer).new(1)
	assert Literal::Array(Numeric) === Literal::Array(Float).new(1.0)

	assert Literal::Array(
		Literal::Array(Numeric)
	) === Literal::Array(
		Literal::Array(Integer)
	).new(
		Literal::Array(Integer).new(1)
	)

	refute Literal::Array(true) === Literal::Array(_Boolean).new(true, false)
	refute Literal::Array(Integer) === Literal::Array(Numeric).new(1, 1.234)
end

test "#initialize" do
	assert_raises(Literal::TypeError) do
		Literal::Array(String).new(1, 2, 3)
	end
end

test "#to_a" do
	array = Literal::Array(Integer).new(1, 2, 3)
	assert_equal array.to_a, [1, 2, 3]
end

test "#to_a doesn't return the internal array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	refute_same array.__value__, array.to_a
end

test "#map maps each item correctly" do
	array = Literal::Array(Integer).new(1, 2, 3)

	mapped = array.map(String, &:to_s)
	assert_equal mapped.to_a, ["1", "2", "3"]
end

test "#map raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.map(Integer, &:to_s)
	end
end

test "#map! maps each item correctly" do
	array = Literal::Array(Integer).new(1, 2, 3)

	array.map!(&:succ)

	assert_equal array.to_a, [2, 3, 4]
end

test "map! raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.map!(&:to_s)
	end
end

test "#[]" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array[0], 1
	assert_equal array[1], 2
	assert_equal array[2], 3
	assert_equal array[3], nil
end

test "#[]= raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises Literal::TypeError do
		array[0] = "1"
	end
end

test "#[]= works as expected" do
	array = Literal::Array(Integer).new(1, 2, 3)

	array[0] = 5
	array[3] = 6

	assert_equal array[0], 5
	assert_equal array[3], 6
end

test "#== compares the Literal::Arrays" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(1, 2, 3)

	assert_equal (array == other), true
end

test "#<< inserts a new item" do
	array = Literal::Array(Integer).new(1, 2, 3)

	array << 4

	assert_equal array.to_a, [1, 2, 3, 4]
end

test "#<< raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array << "4"
	end
end

test "#& performs bitwise AND with another Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(2, 3, 4)

	assert_equal (array & other).to_a, [2, 3]
end

test "#& performs bitwise AND with a regular Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = [2, 3, 4]

	assert_equal (array & other).to_a, [2, 3]
end

test "#* with an integer multiplies the array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	result = array * 2

	assert Literal::Array(Integer) === result
	assert_equal result.to_a, [1, 2, 3, 1, 2, 3]
end

test "#* raises with a negative integer" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(ArgumentError) do
		array * -1
	end
end

test "#* with a string joins the elements" do
	array = Literal::Array(Integer).new(1, 2, 3)
	result = array * ","

	assert_equal result, "1,2,3"
end

test "#+ adds another Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(4, 5)

	result = array + other
	assert Literal::Array(Integer) === result
	assert_equal result.to_a, [1, 2, 3, 4, 5]
end

test "#+ adds an array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = [4, 5]

	result = array + other
	assert Literal::Array(Integer) === result
	assert_equal result.to_a, [1, 2, 3, 4, 5]
end

test "#+ raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(String).new("a", "b")
	other_primitive = ["a", "b"]

	assert_raises(Literal::TypeError) do
		array + other
	end

	assert_raises(Literal::TypeError) do
		array + other_primitive
	end
end

test "#- removes elements from another Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(1)

	result = array - other

	assert_equal result.to_a, [2, 3]
end

test "#- removes elements from an array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = [1]

	result = array - other
	assert_equal result.to_a, [2, 3]
end

test "#<=> works as expected" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal (array <=> [1, 2, 4]), -1
	assert_equal (array <=> [1, 2, 2]), 1
	assert_equal (array <=> [1, 2, 3, 4]), -1
	assert_equal (array <=> [1, 2]), 1
	assert_equal (array <=> [1, 2, 3]), 0
end

test "#<=> works with another Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(1, 2, 4)

	assert_equal (array <=> other), -1
end

test "#sort returns a new sorted array" do
	array = Literal::Array(Integer).new(3, 2, 1)

	result = array.sort

	assert Literal::Array(Integer) === result
	assert_equal result.to_a, [1, 2, 3]
end

test "#sort! sorts the array in place" do
	array = Literal::Array(Integer).new(3, 2, 1)
	array.sort!

	assert_equal array.to_a, [1, 2, 3]
end

test "#sort_by! sorts the array given a block" do
	array = Literal::Array(String).new("Lucy", "Stephen", "Bob")
	array.sort_by!(&:size)

	assert_equal array.to_a, ["Bob", "Lucy", "Stephen"]
end

test "#push appends single value" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.push(4)

	assert_same return_value, array
	assert_equal array.to_a, [1, 2, 3, 4]
end

test "#push appends multiple values" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.push(4, 5)

	assert_same return_value, array
	assert_equal array.to_a, [1, 2, 3, 4, 5]
end

test "#push raises if any type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.push("4")
	end

	assert_raises(Literal::TypeError) do
		array.push(4, "5")
	end
end

test "#assoc returns the correct element" do
	array = Literal::Array(Array).new([1, 2], [3, 4])

	assert_equal array.assoc(1), [1, 2]
	assert_equal array.assoc(3), [3, 4]
end

test "#combination yields to the block" do
	array = Literal::Array(Integer).new(1, 2, 3)
	results = []

	array.combination(2) { |x| results << x }

	assert_equal results, [[1, 2], [1, 3], [2, 3]]
end

test "#combination returns self" do
	array = Literal::Array(Integer).new(1, 2, 3)
	return_value = array.combination(0) { nil }

	assert_same return_value, array
end

test "#compact returns a new Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	result = array.compact

	refute_same array, result
	assert Literal::Array(Integer) === result
	assert_equal result.to_a, [1, 2, 3]
end

test "#compact! returns nil" do
	array = Literal::Array(Integer).new(1, 2, 3)
	return_value = array.compact!

	assert_equal return_value, nil
end

test "#delete deletes the element" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.delete(2)

	assert_equal return_value, 2
	assert_equal array, Literal::Array(Integer).new(1, 3)
end

test "#delete_at deletes the element at the index" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.delete_at(1)

	assert_equal return_value, 2
	assert_equal array, Literal::Array(Integer).new(1, 3)
end

test "#delete_if deletes elements that match the block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.delete_if { |i| i < 2 }

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(2, 3)
end

test "#drop returns a new array with the first n elements removed" do
	array = Literal::Array(Integer).new(1, 2, 3)
	dropped = array.drop(1)

	refute_same dropped, array
	assert Literal::Array(Integer) === dropped
	assert_equal dropped, Literal::Array(Integer).new(2, 3)
end

test "#drop_while returns a new array with the first n elements removed" do
	array = Literal::Array(Integer).new(1, 2, 3)
	dropped = array.drop_while { |i| i < 2 }

	refute_same dropped, array
	assert Literal::Array(Integer) === dropped
	assert_equal dropped, Literal::Array(Integer).new(2, 3)
end

test "#each_index iterates through the indexes" do
	array = Literal::Array(Integer).new(1, 2, 3)
	indexes = []

	array.each_index { |i| indexes << i }

	assert_equal indexes, [0, 1, 2]
end

test "#insert inserts single element at index offset" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.insert(1, 4)

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(1, 4, 2, 3)
end

test "#insert inserts multiple elements at index offset" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.insert(1, 4, 5, 6)

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(1, 4, 5, 6, 2, 3)
end

test "#insert raises if any type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.insert(1, "4")
	end

	assert_raises(Literal::TypeError) do
		array.insert(1, 4, "5", 6)
	end
end

test "#intersect? returns true if the arrays intersect" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other_true = Literal::Array(Integer).new(2, 3, 4)
	other_false = Literal::Array(Integer).new(4, 5, 6)

	assert array.intersect?(other_true)
	refute array.intersect?(other_false)
end

test "#intersection returns an array of the intersection of two arrays" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(2, 3, 4)

	intersection = array.intersection(other, [2])

	assert_equal intersection, Literal::Array(Integer).new(2)
end

test "#join joins the elements into a string" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.join, "123"
	assert_equal array.join(", "), "1, 2, 3"
end

test "#keep_if keeps elements that match the block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.keep_if { |i| i > 1 }

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(2, 3)
end

test "#keep_if returns an enumerator if no block is given" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.keep_if

	assert_equal return_value.class, Enumerator
end

test "#replace replaces with regular Array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.replace([4, 5, 6])

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(4, 5, 6)
end

test "#replace replaces with Literal::Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(4, 5, 6)

	return_value = array.replace(other)

	assert_same return_value, array
	refute_same array, other
	assert_equal array, other
end

test "#replace raises if type of any element in array is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(Literal::TypeError) do
		array.replace([1, "4"])
	end

	assert_raises(Literal::TypeError) do
		array.replace(
			Literal::Array(String).new
		)
	end
end

test "#replace raises with non-array argument" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(ArgumentError) do
		array.replace("not an array")
	end
end

test "#reverse_each iterates through the array in reverse" do
	array = Literal::Array(Integer).new(1, 2, 3)
	results = []

	return_value = array.reverse_each { |i| results << i }

	assert_same return_value, array
	assert_equal results, [3, 2, 1]
end

test "#reverse_each returns an enumerator if no block is given" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.reverse_each

	assert_equal return_value.class, Enumerator
end

test "#values_at returns the values at the given indexes" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.values_at(0), Literal::Array(Integer).new(1)
	assert_equal array.values_at(1), Literal::Array(Integer).new(2)
	assert_equal array.values_at(2), Literal::Array(Integer).new(3)
	assert_equal array.values_at(1..2), Literal::Array(Integer).new(2, 3)

	assert_raises IndexError do
		array.values_at(3)
	end

	assert_raises IndexError do
		array.values_at(-4)
	end

	assert_raises IndexError do
		array.values_at(-4..2)
	end

	assert_raises IndexError do
		array.values_at(1..3)
	end
end

test "#values_at on a nilable array returns the values at the given indexes" do
	array = Literal::Array(_Nilable(Integer)).new(1, 2, 3)

	# TODO: We could do some type narrowing here.
	assert_equal array.values_at(-4), Literal::Array(_Nilable(Integer)).new(nil)
	assert_equal array.values_at(3), Literal::Array(_Nilable(Integer)).new(nil)
end

test "#uniq! removes duplicates" do
	array = Literal::Array(Integer).new(1, 2, 3, 2, 1)

	return_value = array.uniq!

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(1, 2, 3)
end

test "#uniq! returns nil if no duplicates" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.uniq!

	assert_equal return_value, nil
end

test "#uniq returns a new array with duplicates removed" do
	array = Literal::Array(Integer).new(1, 2, 2, 3, 3, 3)

	return_value = array.uniq

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2, 3)
end

test "#| returns a union of two Literal::Arrays" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(Integer).new(2, 3, 4)

	union = array | other

	refute_same union, array
	refute_same union, other

	assert_equal union, Literal::Array(Integer).new(1, 2, 3, 4)
end

test "#| returns a union of a Literal::Array and an Array" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = [2, 3, 4]

	union = array | other

	assert_equal union, Literal::Array(Integer).new(1, 2, 3, 4)
end

test "#| raises if the type is wrong" do
	array = Literal::Array(Integer).new(1, 2, 3)
	other = Literal::Array(String).new("2", "3")
	other_primitive = ["2", "3"]

	assert_raises(Literal::TypeError) do
		array | other
	end

	assert_raises(Literal::TypeError) do
		array | other_primitive
	end
end

test "#sum" do
	assert_equal Literal::Array(Integer).new(1, 2, 3).sum, 6
	assert_equal Literal::Array(String).new("1", "2", "3").sum(&:to_i), 6
end

test "#select returns a new array with elements that match the block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.select { |i| i > 1 }

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(2, 3)
end

test "#select! removes elements that do not match the block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.select! { |i| i > 1 }

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(2, 3)
end

test "#select! empties the array if no elements match the block" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.select! { |i| i > 4 }

	assert_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new
end

test "#narrow" do
	array = Literal::Array(Numeric).new(1, 2, 3)

	return_value = array.narrow(Integer)
	assert Literal::Array(Integer) === return_value
end

test "#narrow with same type" do
	array = Literal::Array(Numeric).new(1, 2, 3)

	assert Literal::Array(Numeric) === array
end

test "#narrow with wrong value" do
	array = Literal::Array(Numeric).new(1, 2, 3.456)

	assert_raises(Literal::TypeError) do
		array.narrow(Integer)
	end
end

test "#narrow with wrong type" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_raises(ArgumentError) do
		array.narrow(Numeric)
	end
end

test "#flatten! flattens the array" do
	array = Literal::Array(Array).new([1, 2], [3, 4])

	return_value = array.flatten!

	assert_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2, 3, 4)
end

test "#flatten! returns nil if no nested arrays" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.flatten!

	assert_equal return_value, nil
end

test "#flatten flattens the array" do
	array = Literal::Array(Array).new([1, 2], [3, 4])

	return_value = array.flatten

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2, 3, 4)
end

test "#flatten with level flattens the array" do
	array = Literal::Array(Array).new([1, 2], [3, 4])

	return_value = array.flatten(1)

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2, 3, 4)
end

test "#fetch" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.fetch(0), 1
	assert_equal array.fetch(1), 2
	assert_equal array.fetch(2), 3

	assert_raises(IndexError) { array.fetch(3) }
end

test "#inspect returns a string representation of the array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.inspect, "Literal::Array(Integer)[1, 2, 3]"
end

test "#to_s returns a string representation of the array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.to_s, "[1, 2, 3]"
end

test "#fetch returns default value if element is missing at index" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.fetch(4, :missing), :missing
end

test "#fetch returns value of block if element is missing at index" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert_equal array.fetch(4) { |index| index * 2 }, 8
end

test "#include? returns true if array contains value" do
	array = Literal::Array(Integer).new(1, 2, 3)

	assert array.include?(2)
	refute array.include?(4)
end

test "#reverse returns a new reversed array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.reverse

	assert_equal return_value, Literal::Array(Integer).new(3, 2, 1)
end

test "#rotate! rotates the array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.rotate!

	assert_same return_value, array
	assert_equal array, Literal::Array(Integer).new(2, 3, 1)
end

test "#rotate rotates the array" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.rotate

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(2, 3, 1)
end

test "#reverse! reverses the array in place" do
	array = Literal::Array(Integer).new(1, 2, 3)

	return_value = array.reverse!

	assert_same return_value, array
end

test "#take takes the first n elements" do
	array = Literal::Array(Integer).new(1, 2, 3, 4, 5)

	return_value = array.take(2)

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2)
end

test "#take_while takes elements where the block returns true" do
	array = Literal::Array(Integer).new(1, 2, 3, 4, 5)

	return_value = array.take_while { |i| i < 3 }

	refute_same return_value, array
	assert_equal return_value, Literal::Array(Integer).new(1, 2)
end

test "#shuffle returns a new shuffled array" do
	array = Literal::Array(Integer).new(1, 2, 3, 4, 5)
	random = Random.new(42)

	return_value = array.shuffle(random:)

	assert_equal return_value, Literal::Array(Integer).new(2, 5, 3, 1, 4)
end

test "#shuffle! shuffles the array" do
	array = Literal::Array(Integer).new(1, 2, 3, 4, 5)
	random = Random.new(42)

	result = array.shuffle!(random:)

	assert_same result, array
	assert_equal result, Literal::Array(Integer).new(2, 5, 3, 1, 4)
end

test "#product with block" do
	a = Literal::Array(Integer).new(1, 2)
	b = Literal::Array(String).new("a", "b")

	yielded = []

	result = a.product(b) { |x, y| yielded << [x, y] }

	assert_same result, a
	assert_equal yielded, [[1, "a"], [1, "b"], [2, "a"], [2, "b"]]
end

test "#product with another Literal::Array" do
	a = Literal::Array(Integer).new(1, 2)
	b = Literal::Array(String).new("a", "b")

	result = a.product(b)

	assert Literal::Array(Literal::Tuple(Integer, String)) === result

	assert_equal result.size, 4
	assert_equal result.first, Literal::Tuple(Integer, String).new(1, "a")
end

test "#transpose with a nested literal tuple" do
	array = Literal::Array(
		Literal::Tuple(Integer, String)
	).new(
		Literal::Tuple(Integer, String).new(1, "a"),
		Literal::Tuple(Integer, String).new(2, "b"),
	)

	assert_equal array.transpose, Literal::Tuple(
		Literal::Array(Integer),
		Literal::Array(String),
	).new(
		Literal::Array(Integer).new(1, 2),
		Literal::Array(String).new("a", "b"),
	)
end

test "#transpose with a nested literal array" do
	array = Literal::Array(Literal::Array(Integer)).new(
		Literal::Array(Integer).new(1, 2),
		Literal::Array(Integer).new(3, 4),
	)

	assert_equal array.transpose, Literal::Array(
		Literal::Array(Integer)
	).new(
		Literal::Array(Integer).new(1, 3),
		Literal::Array(Integer).new(2, 4),
	)
end

test "#transpose with a nested literal array with different lengths raises an IndexError" do
	array = Literal::Array(Literal::Array(Integer)).new(
		Literal::Array(Integer).new(1, 2),
		Literal::Array(Integer).new(3, 4, 5),
	)

	assert_raises(IndexError) do
		array.transpose
	end
end

test "#transpose with a nested regular array" do
	array = Literal::Array(_Array(Integer)).new(
		[1, 2],
		[3, 4],
	)

	assert_equal array.transpose, [
		[1, 3],
		[2, 4],
	]
end

test "#zip with other literal arrays when all the lengths match" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1, 2)
	c = Literal::Array(Symbol).new(:a, :b)

	assert_equal a.zip(b, c), Literal::Array(
		Literal::Tuple(String, Integer, Symbol)
	).new(
		Literal::Tuple(String, Integer, Symbol).new("a", 1, :a),
		Literal::Tuple(String, Integer, Symbol).new("b", 2, :b),
	)
end

test "#zip with other regular arrays" do
	a = Literal::Array(String).new("a", "b")
	b = [1, 2]
	c = [:a, :b]

	assert_equal a.zip(b, c), Literal::Array(
		Literal::Tuple(String, _Any?, _Any?)
	).new(
		Literal::Tuple(String, _Any?, _Any?).new("a", 1, :a),
		Literal::Tuple(String, _Any?, _Any?).new("b", 2, :b),
	)
end

test "#zip with other literal arrays where one of the others length is not the max length and the type is not nilable" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1)
	c = Literal::Array(Symbol).new(:a, :b)

	assert_raises ArgumentError do
		a.zip(b, c)
	end
end

test "#zip with literal arrays where our length is not the max length and the type is not nilable" do
	a = Literal::Array(String).new("a")
	b = Literal::Array(Integer).new(1, 2)
	c = Literal::Array(Symbol).new(:a, :b)

	assert_raises ArgumentError do
		a.zip(b, c)
	end
end

test "#zip when our length is not the max length but the type is nilable" do
	a = Literal::Array(_Nilable(String)).new("a")
	b = [1, 2]
	c = [:a, :b]

	assert_equal a.zip(b, c), Literal::Array(
		Literal::Tuple(_Nilable(String), _Any, _Any)
	).new(
		Literal::Tuple(_Nilable(String), _Any, _Any).new("a", 1, :a),
		Literal::Tuple(_Nilable(String), _Any, _Any).new(nil, 2, :b),
	)
end

test "#zip with others length is not the max length but the types are nilable" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(_Nilable(Integer)).new(1)
	c = [:a]

	assert_equal a.zip(b, c), Literal::Array(
		Literal::Tuple(String, _Nilable(Integer), _Any)
	).new(
		Literal::Tuple(String, _Nilable(Integer), _Any).new("a", 1, :a),
		Literal::Tuple(String, _Nilable(Integer), _Any).new("b", nil, nil),
	)
end

test "#zip with a block" do
	a = Literal::Array(String).new("a", "b")
	b = Literal::Array(Integer).new(1, 2)
	c = [:a, :b]

	results = []

	return_value = a.zip(b, c) { |it| results << it }

	assert_equal results, [
		Literal::Tuple(String, Integer, _Any).new("a", 1, :a),
		Literal::Tuple(String, Integer, _Any).new("b", 2, :b),
	]

	assert_equal return_value, nil
end
