# frozen_string_literal: true

include Literal::Types

# Asserts the two types are equivalent — each a subtype of the other.
def assert_type_equal(actual, expected)
	assert Literal.subtype?(actual, expected)
	assert Literal.subtype?(expected, actual)
end

# Asserts `hash` is a Literal::Hash with exactly the given types and entries.
def assert_literal_hash(hash, key_type:, value_type:, entries:)
	assert Literal::Hash === hash
	assert_type_equal hash.__key_type__, key_type
	assert_type_equal hash.__value_type__, value_type
	assert_equal hash.to_h, entries
end

# Generic

test "Generic#new creates a checked literal hash" do
	hash = Literal::Hash(String, Integer).new({ "a" => 1 })

	assert_literal_hash hash, key_type: String, value_type: Integer, entries: { "a" => 1 }
end

test "Generic#new defaults to an empty hash" do
	assert_literal_hash Literal::Hash(String, Integer).new, key_type: String, value_type: Integer, entries: {}
end

test "Generic#new raises when a key or value doesn't match" do
	assert_raises(Literal::TypeError) do
		Literal::Hash(String, Integer).new({ 1 => 1 })
	end

	assert_raises(Literal::TypeError) do
		Literal::Hash(String, Integer).new({ "a" => "1" })
	end
end

test "Generic#[] is equivalent to Generic#new" do
	assert_equal Literal::Hash(String, Integer)["a" => 1], Literal::Hash(String, Integer).new({ "a" => 1 })
end

test "Generic#coerce converts a plain hash" do
	hash = Literal::Hash(Symbol, Integer).coerce({ a: 1 })

	assert_literal_hash hash, key_type: Symbol, value_type: Integer, entries: { a: 1 }

	assert_raises(Literal::TypeError) do
		Literal::Hash(Symbol, Integer).coerce({ "a" => 1 })
	end
end

test "Generic#coerce passes matching literal hashes through unchanged" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_same Literal::Hash(Symbol, Integer).coerce(hash), hash
	assert_same Literal::Hash(Symbol, Numeric).coerce(hash), hash
	assert_equal Literal::Hash(String, Integer).coerce(hash), nil
end

test "Generic#=== matches covariantly in keys and values" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert Literal::Hash(Symbol, Integer) === hash
	assert Literal::Hash(Symbol, Numeric) === hash
	assert Literal::Hash(_Union(Symbol, String), Integer) === hash

	refute Literal::Hash(String, Integer) === hash
	refute Literal::Hash(Symbol, String) === hash
	refute Literal::Hash(Symbol, Integer) === { a: 1 }
end

test "Generic#== compares both types" do
	assert_equal Literal::Hash(Symbol, Integer), Literal::Hash(Symbol, Integer)
	refute_equal Literal::Hash(Symbol, Integer), Literal::Hash(Symbol, String)
	refute_equal Literal::Hash(Symbol, Integer), Literal::Hash(String, Integer)
end

test "Generic subtyping is covariant" do
	assert Literal.subtype?(Literal::Hash(Symbol, Integer), Literal::Hash(Symbol, Numeric))
	refute Literal.subtype?(Literal::Hash(Symbol, Numeric), Literal::Hash(Symbol, Integer))
end

test "literal hash types and plain hash types are never subtypes of each other" do
	refute Literal.subtype?(Literal::Hash(Symbol, Integer), _Hash(Symbol, Integer))
	refute Literal.subtype?(_Hash(Symbol, Integer), Literal::Hash(Symbol, Integer))
	refute _Hash(Symbol, Integer) === Literal::Hash(Symbol, Integer).new({ a: 1 })
end

test "Generic#inspect" do
	assert_equal Literal::Hash(String, Integer).inspect, "Literal::Hash(String, Integer)"
end

# Construction

test "#initialize copies the input, so the caller's reference is harmless" do
	input = { a: 1 }
	hash = Literal::Hash(Symbol, Integer).coerce(input)

	input[:b] = "nope"

	assert_equal hash.to_h, { a: 1 }
end

# Equality

test "#== is structural" do
	assert_equal Literal::Hash(Symbol, Integer).new({ a: 1 }), Literal::Hash(Symbol, Integer).new({ a: 1 })
	refute_equal Literal::Hash(Symbol, Integer).new({ a: 1 }), Literal::Hash(Symbol, Integer).new({ a: 2 })
	refute_equal Literal::Hash(Symbol, Integer).new({ a: 1 }), { a: 1 }
end

test "#eql? requires the same types" do
	a = Literal::Hash(Symbol, Integer).new({ a: 1 })
	b = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert a.eql?(b)
	assert_equal a.hash, b.hash

	refute Literal::Hash(Symbol, Integer).new.eql?(Literal::Hash(Symbol, String).new)
end

# Reads

test "#[], #fetch, #dig, #key?, #value?, #size and #empty?" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2 })

	assert_equal hash[:a], 1
	assert_equal hash[:c], nil
	assert_equal hash.fetch(:b), 2
	assert_equal hash.fetch(:c, 3), 3
	assert_raises(KeyError) { hash.fetch(:c) }
	nested = Literal::Hash(Symbol, Literal::Hash(Symbol, Integer)).new({ a: Literal::Hash(Symbol, Integer).new({ b: 1 }) })
	assert_equal nested.dig(:a, :b), 1
	assert hash.key?(:a)
	refute hash.key?(:c)
	assert hash.value?(2)
	refute hash.value?(3)
	assert_equal hash.size, 2
	refute hash.empty?
	assert Literal::Hash(Symbol, Integer).new.empty?
end

test "#each yields pairs and returns self" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2 })
	yielded = []

	assert_same hash.each { |k, v| yielded << [k, v] }, hash
	assert_equal yielded, [[:a, 1], [:b, 2]]
end

test "#keys and #values return typed literal arrays" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2 })

	keys = hash.keys
	values = hash.values

	assert Literal::Array(Symbol) === keys
	assert_equal keys.to_a, [:a, :b]

	assert Literal::Array(Integer) === values
	assert_equal values.to_a, [1, 2]
end

test "#to_h and #to_hash return detached plain copies, enabling double-splats" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	plain = hash.to_h
	refute_same plain, hash.__value__

	plain[:b] = 2
	assert_equal hash.to_h, { a: 1 }

	kwargs = -> (**kw) { kw }
	assert_equal kwargs.call(**hash), { a: 1 }
end

test "#inspect" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_equal hash.inspect, "Literal::Hash(Symbol, Integer)#{{ a: 1 }.inspect}"
end

# Type-preserving copies

test "#merge checks entries at the boundary" do
	hash = Literal::Hash(Symbol, Numeric).new({ a: 1 })

	merged = hash.merge(Literal::Hash(Symbol, Integer).new({ b: 2 }), { c: 3.5 })

	assert_literal_hash merged, key_type: Symbol, value_type: Numeric, entries: { a: 1, b: 2, c: 3.5 }
	assert_equal hash.to_h, { a: 1 }

	assert_raises(Literal::TypeError) { hash.merge({ d: "nope" }) }
	assert_raises(Literal::TypeError) { hash.merge(Literal::Hash(Symbol, String).new({ d: "nope" })) }
	assert_raises(ArgumentError) { hash.merge("nope") }
end

test "#merge with a conflict block checks the resolved values" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	merged = hash.merge({ a: 2 }) { |_key, old, new| old + new }
	assert_equal merged.to_h, { a: 3 }

	assert_raises(Literal::TypeError) do
		hash.merge({ a: 2 }) { |_key, _old, _new| "nope" }
	end
end

test "#select and #reject return typed copies" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2 })

	selected = hash.select { |_k, v| v.even? }
	rejected = hash.reject { |_k, v| v.even? }

	assert_literal_hash selected, key_type: Symbol, value_type: Integer, entries: { b: 2 }
	assert_literal_hash rejected, key_type: Symbol, value_type: Integer, entries: { a: 1 }
	assert_equal hash.size, 2
end

test "#except and #slice return typed copies" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2, c: 3 })

	assert_literal_hash hash.except(:a), key_type: Symbol, value_type: Integer, entries: { b: 2, c: 3 }
	assert_literal_hash hash.slice(:a, :b), key_type: Symbol, value_type: Integer, entries: { a: 1, b: 2 }
end

test "#invert swaps the key and value types" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_literal_hash hash.invert, key_type: Integer, value_type: Symbol, entries: { 1 => :a }
end

test "#compact narrows a nilable value type" do
	hash = Literal::Hash(Symbol, _Nilable(Integer)).new({ a: 1, b: nil })

	compacted = hash.compact

	assert_literal_hash compacted, key_type: Symbol, value_type: Integer, entries: { a: 1 }
	assert_equal hash.to_h, { a: 1, b: nil }
end

test "#compact on a non-nilable value type returns a detached copy" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	compacted = hash.compact

	assert_literal_hash compacted, key_type: Symbol, value_type: Integer, entries: { a: 1 }
	refute_same compacted.__value__, hash.__value__
end

# Type-changing transforms

test "#transform_values requires an explicit type" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	transformed = hash.transform_values(String, &:to_s)

	assert_literal_hash transformed, key_type: Symbol, value_type: String, entries: { a: "1" }

	assert_raises(Literal::TypeError) do
		hash.transform_values(Integer, &:to_s)
	end
end

test "#transform_keys requires an explicit type" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	transformed = hash.transform_keys(String, &:name)

	assert_literal_hash transformed, key_type: String, value_type: Integer, entries: { "a" => 1 }

	assert_raises(Literal::TypeError) do
		hash.transform_keys(Integer, &:name)
	end
end

# Checked mutations

test "#[]= checks the key and the value" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	hash[:b] = 2
	assert_equal hash.to_h, { a: 1, b: 2 }

	assert_raises(Literal::TypeError) { hash["c"] = 3 }
	assert_raises(Literal::TypeError) { hash[:c] = "3" }
	assert_equal hash.to_h, { a: 1, b: 2 }
end

test "#merge! checks every source before mutating" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_same hash.merge!(Literal::Hash(Symbol, Integer).new({ b: 2 }), { c: 3 }), hash
	assert_equal hash.to_h, { a: 1, b: 2, c: 3 }

	assert_raises(Literal::TypeError) { hash.merge!({ d: "nope" }) }
	assert_equal hash.to_h, { a: 1, b: 2, c: 3 }
end

test "#merge! with a conflict block checks the resolved values" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_same hash.merge!({ a: 2 }) { |_key, old, new| old + new }, hash
	assert_equal hash.to_h, { a: 3 }

	assert_raises(Literal::TypeError) do
		hash.merge!({ a: 2 }) { |_key, _old, _new| "nope" }
	end

	assert_equal hash.to_h, { a: 3 }
end

test "#delete returns the removed value" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_equal hash.delete(:a), 1
	assert_equal hash.delete(:a), nil
	assert hash.empty?
end

test "#select!, #reject!, #compact! and #clear return self" do
	hash = Literal::Hash(Symbol, _Nilable(Integer)).new({ a: 1, b: 2, c: nil })

	assert_same hash.compact!, hash
	assert_equal hash.to_h, { a: 1, b: 2 }
	assert_type_equal hash.__value_type__, _Nilable(Integer)

	assert_same hash.select! { |_k, v| v.even? }, hash
	assert_equal hash.to_h, { b: 2 }

	assert_same hash.reject! { |_k, v| v.even? }, hash
	assert hash.empty?

	assert_same hash.clear, hash
end

# Copying and freezing

test "#dup does not share storage with the original" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })
	copy = hash.dup

	copy[:b] = 2

	assert_equal copy.to_h, { a: 1, b: 2 }
	assert_equal hash.to_h, { a: 1 }
end

test "#freeze freezes the underlying storage" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 }).freeze

	assert hash.frozen?
	assert_raises(FrozenError) { hash[:b] = 2 }
	assert_raises(FrozenError) { hash.clear }
end

test "#clone of a frozen hash is frozen" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 }).freeze
	copy = hash.clone

	assert copy.frozen?
	assert_raises(FrozenError) { copy[:b] = 2 }
end

# Narrowing and widening

test "#narrow returns a detached hash with narrower types" do
	hash = Literal::Hash(Symbol, Numeric).new({ a: 1 })

	narrowed = hash.narrow(value_type: Integer)

	assert_literal_hash narrowed, key_type: Symbol, value_type: Integer, entries: { a: 1 }
	refute_same narrowed.__value__, hash.__value__

	assert_raises(Literal::TypeError) { Literal::Hash(Symbol, Numeric).new({ a: 1.5 }).narrow(value_type: Integer) }
	assert_raises(ArgumentError) { hash.narrow(value_type: String) }
end

test "#widen returns a detached hash with wider types" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	widened = hash.widen(value_type: Numeric)

	assert_literal_hash widened, key_type: Symbol, value_type: Numeric, entries: { a: 1 }

	widened[:b] = 1.5
	assert_equal hash.to_h, { a: 1 }

	assert_raises(ArgumentError) { hash.widen(value_type: String) }
end

# Enumerable

test "supported Enumerable methods work" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1, b: 2 })

	assert hash.all? { |_k, v| v > 0 }
	assert hash.any? { |_k, v| v.even? }
	assert hash.none? { |_k, v| v > 2 }
	assert hash.one? { |_k, v| v.even? }
	assert_equal hash.find { |_k, v| v.even? }, [:b, 2]
	assert_equal hash.reduce(0) { |sum, (_k, v)| sum + v }, 3
	assert Enumerable === hash
end

test "unsupported Enumerable methods and aliases are removed" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	%i[
		group_by
		partition
		zip
		tally
		map
		flat_map
		filter_map
		entries
		to_a
		lazy
		grep
		detect
		inject
		collect
		filter
		member?
		include?
		has_key?
		has_value?
		store
		update
		each_pair
		length
		count
	].each do |method|
		refute hash.respond_to?(method)
	end
end

test "block-transform methods require a block" do
	hash = Literal::Hash(Symbol, Integer).new({ a: 1 })

	assert_raises(ArgumentError) { hash.select }
	assert_raises(ArgumentError) { hash.reject }
	assert_raises(ArgumentError) { hash.transform_values(String) }
	assert_raises(ArgumentError) { hash.transform_keys(String) }
end
