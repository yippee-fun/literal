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
	assert_equal type.tag_for(:other), nil
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
