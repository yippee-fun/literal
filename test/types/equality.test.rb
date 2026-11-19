# frozen_string_literal: true

include Literal::Types

def assert_value_equal(a, b)
	assert_equal a, b
	assert a.eql?(b)
	assert_equal a.hash, b.hash
end

test "types built from equal members are equal" do
	predicate = proc { true }

	[
		-> { _Array(String) },
		-> { _Array(_Array(String)) },
		-> { _Class(Numeric) },
		-> { _Constraint(String, size: 1..3) },
		-> { _Descendant(Numeric) },
		-> { _DraftState(String) },
		-> { _Enumerable(String) },
		-> { _Frozen(String) },
		-> { _Hash(String, Integer) },
		-> { _Instance(String) },
		-> { _Interface(:to_s, :to_str) },
		-> { _Kind(Numeric) },
		-> { _Map(name: String, age: Integer) },
		-> { _Nilable(String) },
		-> { _Not(String) },
		-> { _Predicate("anything", &predicate) },
		-> { _Range(Integer) },
		-> { _SameObject(:a) },
		-> { _Set(String) },
		-> { _TaggedUnion(a: String, b: Integer) },
		-> { _Tuple(String, Integer) },
		-> { _Union(String, Integer, :a, [1]) },
		-> { Literal::Draft::Type.new(String) },
	].each do |build|
		assert_value_equal build.call, build.call
	end
end

test "types built from different members are not equal" do
	refute_equal _Array(String), _Array(Symbol)
	refute_equal _Array(String), _Set(String)
	refute_equal _Hash(String, Integer), _Hash(String, Float)
	refute_equal _Constraint(String, size: 1), _Constraint(String, size: 2)
	refute_equal _Tuple(String, Integer), _Tuple(Integer, String)
	refute_equal _Predicate("anything") { true }, _Predicate("anything") { true }
	refute_equal _SameObject(+"a"), _SameObject(+"a")
	refute_equal _Union(1, String), _Union(1.0, String)
end

test "deferred types are equal only to themselves" do
	deferred = _Deferred { String }

	assert_equal deferred, deferred
	refute_equal _Deferred { String }, _Deferred { String }
	assert_value_equal _Array(deferred), _Array(deferred)
end

test "== ignores the order of union members but eql? doesn't" do
	assert_equal _Union(String, Integer), _Union(Integer, String)
	refute _Union(String, Integer).eql?(_Union(Integer, String))

	assert_equal _TaggedUnion(a: String, b: Integer), _TaggedUnion(b: Integer, a: String)
	refute _TaggedUnion(a: String, b: Integer).eql?(_TaggedUnion(b: Integer, a: String))
end

test "union == compares members the way the union deduplicates them" do
	refute_equal _Union(_Array(1), _Array(1.0)), _Union(_Array(1), _Array(2))
	refute_equal _Union(_Array(1), _Array(2)), _Union(_Array(1), _Array(1.0))
end

test "equal members are deduplicated in a union" do
	assert_equal _Union(_Array(String), _Array(String)).inspect, "_Array(String)"
end

test "recursive types hash without recursing" do
	json = nil
	json = _Union(String, nil, _Array(_Deferred { json }))

	assert_equal json.hash, json.hash
	assert_equal json, json
end

test "equal types defined as different constants keep their own names" do
	tracked = Module.new
	tracked.const_set(:First, _Array(String))
	tracked.const_set(:Second, _Array(String))

	assert_equal tracked::First.name&.split("::")&.last, "First"
	assert_equal tracked::Second.name&.split("::")&.last, "Second"
	assert_equal tracked::First.name&.split("::")&.last, "First"
end

test "serialization reuses the cache entry of an equal type" do
	context = Literal::SerializationContext.new

	context.serialize(["a"], type: _Array(String))

	assert context.instance_variable_get(:@serializer_cache).key?(_Array(String))
end

test "types can hold matchers without a hash method" do
	matcher = Class.new(BasicObject) { def ===(_value) = true }.new

	[
		_Array(matcher),
		_Set(matcher),
		_Hash(matcher, matcher),
		_Map(a: matcher),
		_Tuple(matcher),
		_Nilable(matcher),
		_Not(matcher),
		_Enumerable(matcher),
		_Range(matcher),
		_Constraint(matcher, size: 1),
	].each do |type|
		assert Integer === type.hash
		assert type == type
	end
end

test "types hold frozen copies of their members, so eql? and hash stay in agreement" do
	objects, properties, types, shape, message = [String], { size: 1 }, [String], { a: String }, +"anything"

	constraint = Literal::Types::ConstraintType.new(objects, properties)
	tuple = Literal::Types::TupleType.new(types)
	map = Literal::Types::MapType.new(shape)
	predicate = _Predicate(message) { true }

	[
		constraint.object_constraints,
		constraint.property_constraints,
		tuple.types,
		map.shape,
		predicate.message,
		_Pattern(/a/) { true }.message,
		_Union(String, 1).types,
		_TaggedUnion(a: String).members,
		_Interface(:to_s).methods,
	].each { |member| assert member.frozen? }

	objects << Integer
	properties[:length] = 2
	types << Integer
	shape[:b] = Integer
	message << "!"

	assert_value_equal constraint, _Constraint(String, size: 1)
	assert_value_equal tuple, _Tuple(String)
	assert_value_equal map, _Map(a: String)
	assert_equal predicate.message, "anything"
end
