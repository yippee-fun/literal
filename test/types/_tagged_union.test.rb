# frozen_string_literal: true

include Literal::Types

test "#members" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type.members, { name: String, age: Integer }
end

test "#[]" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type[:name], String
	assert_equal type[:age], Integer
	assert_equal type[:missing], nil
end

test "#tag_for" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type.tag_for("Alice"), :name
	assert_equal type.tag_for(42), :age
	assert_raises(Literal::ArgumentError) { type.tag_for(:other) }
end

test "#type_of" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type.type_of("Alice"), String
	assert_equal type.type_of(42), Integer
	assert_raises(Literal::ArgumentError) { type.type_of(:other) }
end

test "#resolve" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type.resolve("Alice"), [:name, String]
	assert_equal type.resolve(42), [:age, Integer]
	assert_raises(Literal::ArgumentError) { type.resolve(:other) }
end

test "#inspect" do
	type = _TaggedUnion(name: String, age: Integer)

	assert_equal type.inspect, "_TaggedUnion(name: String, age: Integer)"
end

test "===" do
	type = _TaggedUnion(name: String, age: Integer, flag: _Boolean)

	assert type === "Alice"
	assert type === 42
	assert type === true
	assert type === false

	refute type === :symbol
	refute type === nil
end

test "nested tagged unions are flattened" do
	type = _TaggedUnion(
		name: String,
		**_TaggedUnion(age: Integer, flag: _Boolean).members,
	)

	assert_equal type.inspect, "_TaggedUnion(name: String, age: Integer, flag: _Boolean)"
end

test "raises on empty members" do
	assert_raises(Literal::ArgumentError) { _TaggedUnion }
end

test "hierarchy: tagged union vs tagged union" do
	assert_subtype _TaggedUnion(name: String), _TaggedUnion(name: String)
	assert_subtype _TaggedUnion(name: String), _TaggedUnion(name: String, age: Integer)
	assert_subtype _TaggedUnion(name: String), _TaggedUnion(name: Comparable)

	refute_subtype _TaggedUnion(name: String, age: Integer), _TaggedUnion(name: String)
	refute_subtype _TaggedUnion(name: String), _TaggedUnion(age: Integer)
end

test "hierarchy: plain type vs tagged union" do
	assert_subtype String, _TaggedUnion(name: String, age: Integer)
	assert_subtype String, _TaggedUnion(name: Comparable)
	assert_subtype Integer, _TaggedUnion(name: String, age: Integer)

	refute_subtype Symbol, _TaggedUnion(name: String, age: Integer)
end

test "hierarchy: tagged union vs union" do
	assert_subtype _TaggedUnion(name: String, age: Integer), _Union(String, Integer)
	assert_subtype _TaggedUnion(name: String), _Union(String, Integer)

	refute_subtype _TaggedUnion(name: String, age: Integer), _Union(String)
end

test "hierarchy: union vs tagged union" do
	assert_subtype _Union(String, Integer), _TaggedUnion(name: String, age: Integer)
	assert_subtype _Union(String), _TaggedUnion(name: String, age: Integer)

	refute_subtype _Union(String, Symbol), _TaggedUnion(name: String, age: Integer)
end

test "error message" do
	error = assert_raises Literal::TypeError do
		Literal.check(:symbol, _TaggedUnion(name: String, age: Integer))
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		  Expected: _TaggedUnion(name: String, age: Integer)
		  Actual (Symbol): :symbol
	ERROR
end

test "resolution picks the most specific matching member" do
	parent = Class.new
	child = Class.new(parent)

	[
		_TaggedUnion(parent:, child:),
		_TaggedUnion(child:, parent:),
	].each do |type|
		assert_equal type.tag_for(child.new), :child
		assert_equal type.type_of(child.new), child
		assert_equal type.resolve(child.new), [:child, child]
		assert_equal type.resolve(parent.new), [:parent, parent]
	end
end

test "resolution breaks ties between incomparable members by declaration order" do
	both = Class.new { include Comparable, Enumerable }.new

	assert_equal _TaggedUnion(comparable: Comparable, enumerable: Enumerable).tag_for(both), :comparable
	assert_equal _TaggedUnion(enumerable: Enumerable, comparable: Comparable).tag_for(both), :enumerable
	assert_equal _TaggedUnion(first: String, second: String).tag_for("a"), :first
end

test "constructing a tagged union does not materialize deferred members" do
	materialized = false
	deferred = _Deferred do
		materialized = true
		Integer
	end
	type = _TaggedUnion(string: String, integer: deferred)

	assert type === "a"
	refute materialized

	assert_equal type.tag_for(1), :integer
	assert materialized
end

test "resolution does not materialize deferred members a value doesn't match" do
	deferred = _Deferred { raise "materialized" }
	type = _TaggedUnion(string: String, integers: _Array(Integer), later: _Array(deferred))

	assert_equal type.tag_for("a"), :string
end

if defined?(Ractor)
	test "a tagged union is Ractor-shareable and resolves once shared" do
		type = Ractor.make_shareable(_TaggedUnion(string: String, integer: Integer))

		assert Ractor.shareable?(type)
		assert_equal type.resolve(1), [:integer, Integer]
	end
end

test "a cyclic value re-entering a tagged union through a proc member does not match" do
	tagged = _TaggedUnion(leaf: Integer, branch: _Array(-> (value) { tagged === value }))
	array = [1]
	array << array

	refute tagged === array
	assert tagged === [1, [2, []]]
end

test "resolution finds literal members like a union" do
	type = _TaggedUnion(one: 1, float: Float, a: "a", string: String)

	assert_equal type.resolve(1), [:one, 1]
	assert_equal type.resolve(1.0), [:float, Float]
	assert_equal type.resolve(1r), [:one, 1]
	assert_equal type.resolve("a"), [:a, "a"]
	assert_equal type.resolve("b"), [:string, String]
	assert_equal _TaggedUnion(float: 1.0, integer: 1).tag_for(1), :integer
	assert_equal _TaggedUnion(first: 1, second: 1).tag_for(1), :first
end

test "literal members match with == like a union's, so === agrees with resolution" do
	literal = +"x"
	def literal.===(value) = value == "y"
	type = _TaggedUnion(string: literal, integer: Integer)

	assert type === "x"
	refute type === "y"
	assert_equal type.tag_for("x"), :string
end

test "a tagged union can hold a matcher without a hash method" do
	matcher = Class.new(BasicObject) { def ===(_value) = true }.new

	assert _TaggedUnion(any: matcher) === 1
end

test "a value re-entering a tagged union through its own methods does not match" do
	tagged = nil
	reader = Class.new { define_method(:name) { tagged === self } }
	tagged = _TaggedUnion(string: String, named: _Constraint(name: true))

	refute tagged === reader.new
end
