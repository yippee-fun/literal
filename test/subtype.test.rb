# frozen_string_literal: true

test "literal values are subtypes of their module supertypes" do
	assert_subtype "Hello", String
	assert_subtype "Hello", Object
	assert_subtype "Hello", Comparable

	assert_subtype :hello, Symbol
	assert_subtype :hello, Object

	assert_subtype [], Array
	assert_subtype [], Enumerable
	assert_subtype [], Object

	assert_subtype({}, Hash)
	assert_subtype({}, Enumerable)
	assert_subtype({}, Object)

	date = Date.new(2025, 1, 13)

	# A date is == to its astronomical Julian day number.
	assert date == date.ajd
	refute_subtype date, Date
	assert_subtype date, Comparable
	assert_subtype date, Object
end

include Literal::Types

test "numeric literals are bounded by Numeric, not their own class" do
	# 10 admits 10.0, 10r and BigDecimal("10") via ==, so Integer is not a
	# sound bound. Class-anchored spellings are.
	assert_subtype 10, Numeric
	assert_subtype 10, 5..15
	assert_subtype 1.5, Numeric

	refute_subtype 10, Integer
	refute_subtype 1.5, Float

	assert_subtype _Integer(10), Integer
	assert_subtype _SameObject(10), Integer
	assert_subtype _Constraint(10, integer?: true), Integer

	refute_subtype _Constraint(10, integer?: false), Integer
	refute_subtype _SameObject(10.0), Integer
end

test "recursive types can be compared" do
	json_data = nil
	json_data = _Union(
		String, Integer, Float, true, false, nil,
		_Deferred { _Array(json_data) },
		_Deferred { _Hash(String, json_data) },
	)

	strict_json_data = nil
	strict_json_data = _Union(
		String, Integer,
		_Deferred { _Array(strict_json_data) },
	)

	assert_subtype json_data, json_data
	assert_subtype strict_json_data, json_data
	assert_subtype _Array(strict_json_data), _Array(json_data)

	refute_subtype json_data, strict_json_data
	refute_subtype _Array(json_data), _Array(strict_json_data)
end

test "results resting on a failed coinductive assumption are not memoized" do
	a = b = left = right = nil
	a = _Union(String, _Deferred { left })
	b = _Union(String, _Deferred { right })
	left = _Tuple(a, Symbol)
	right = _Tuple(b, String)
	other = _Tuple(b, Symbol)

	refute_subtype left, other
	refute_subtype left, _Union(right, other)
end

test "range literals compare as continuous intervals" do
	assert_subtype (1..4), (1..4)
	assert_subtype (1...4), (1..4)
	assert_subtype (2..3), (1..4)
	assert_subtype (2..3), (1..)
	assert_subtype (2..3), (..4)
	assert_subtype (1..4), (nil..nil)
	assert_subtype (1.0..4.0), (1..4)

	refute_subtype (1...5), (1..4)
	refute_subtype (1..4), (1...4)
	refute_subtype (0..4), (1..4)
	refute_subtype (1..), (1..4)
	refute_subtype (..4), (1..4)
	refute_subtype ("a".."z"), (1..4)
	refute_subtype _Float(1...5), _Constraint(Numeric, 1..4)
end

test "literal types are subtypes of the modules bounding their members" do
	assert_subtype _Array(String), Array
	assert_subtype _Array(String), Enumerable
	assert_subtype _Tuple(String), Array
	assert_subtype _Hash(String, Integer), Hash
	assert_subtype _Map(a: String), Hash
	assert_subtype _Set(String), Set
	assert_subtype _Range(Integer), Range
	assert_subtype _Enumerable(String), Enumerable
	assert_subtype _Class(String), Class
	assert_subtype _Descendant(String), Class
	assert_subtype _Descendant(Enumerable), Module
	assert_subtype _Frozen(String), String
	assert_subtype _Boolean, Object
	assert_subtype _Nilable(String), Object
	assert_subtype _JSONData, Object
	assert_subtype _TaggedUnion(a: String, b: Integer), Comparable

	refute_subtype _Array(String), Hash
	refute_subtype _Tuple(String), String
	refute_subtype _Class(String), String
	refute_subtype _Descendant(Enumerable), Class
	refute_subtype _Frozen(String), Symbol
	refute_subtype _Boolean, TrueClass
	refute_subtype _Nilable(String), String
	refute_subtype _JSONData, Comparable
	refute_subtype _TaggedUnion(a: String, b: Array), Comparable
end

test "a union is a subtype of anything all its members are subtypes of" do
	assert_subtype _Union(true, false), _Boolean
	assert_subtype _Nilable(String), _JSONData
	assert_subtype _Union(String, Integer), _JSONData
	assert_subtype _TaggedUnion(a: String, b: Integer), _JSONData
	assert_subtype _Union(String, _Nilable(Integer)), _Nilable(_JSONData)
	assert_subtype _Union(1, 2), 0..5
	assert_subtype _Union(String, Symbol), _Interface(:to_s)
	assert_subtype _Union(_Array(String), _Array(Integer)), _Array(_Union(String, Integer))

	refute_subtype _Union(true, nil), _Boolean
	refute_subtype _Nilable(String), _JSONData(String)
	refute_subtype _Union(String, Symbol), _JSONData
	refute_subtype _TaggedUnion(a: String, b: Symbol), String
end

test "a serializable value type is not necessarily a serializable type" do
	context = Literal::SerializationContext.new

	assert Literal.subtype?(_Union(String, Symbol), context.type)
	refute context.kind === _Union(String, Symbol)
	refute context.property_kind === _Union(String, Symbol, Literal::Undefined)
	assert context.property_kind === _Deferred { _Optional(String) }
end

test "<= on a type agrees with subtype?" do
	assert _Nilable(Integer) <= _Nilable(Numeric)
	assert _Union(true, false) <= _Boolean
	assert _TaggedUnion(a: String, b: Integer) <= _JSONData
	refute _Nilable(String) <= _JSONData(String)
end

test "a literal's properties hold only when its bound entails them" do
	# Literals admit every value == to them: +"x" == "x" but isn't frozen, and
	# [1.0] == [1] but its first element isn't an Integer.
	refute_subtype "x", _Constraint(String, frozen?: true)
	refute_subtype "x", _Frozen(String)
	refute_subtype [1], _Constraint(Array, first: Integer)
	refute_subtype({ a: 1 }, _Constraint(Hash, size: 1..))
	refute_subtype 1, _Interface(:<)

	assert_subtype "x", _Constraint(String, Comparable)
	assert_subtype [1], _Constraint(Array, Enumerable)

	# Symbols, true, false and nil are == only to themselves.
	assert_subtype :a, _Constraint(Symbol, size: 1)
	assert_subtype nil, _Constraint(NilClass, nil?: true)
	assert_subtype :a, _Frozen(_Interface(:to_proc))
end

test "a literal is a subtype of whatever its bound is a subtype of" do
	assert_subtype "x", _JSONData
	assert_subtype ["x"], _Constraint(Array, Enumerable)
	assert_subtype :a, _Interface(:to_proc)
	assert_subtype Date.new(2025, 1, 1), _Interface(:<=>)
	refute_subtype Date.new(2025, 1, 1), _Interface(:jd)

	refute_subtype 1, _JSONData
	refute_subtype "x", _Interface(:foo)
end

test "a type is a subtype of an intersection of types it is a subtype of" do
	assert_subtype _Array(String), _Constraint(Array, Enumerable)
	refute_subtype _Array(String), _Constraint(Array, size: 1)
end

test "a union's own comparison operators distribute it" do
	union = _Union(String, _Array(Integer), 1)
	nilable = _Nilable(String)
	tagged = _TaggedUnion(string: String, integer: Integer)
	result = Literal::Result(String, Integer)

	[union, nilable, tagged, result].each do |type|
		assert type <= Object
		assert type >= type
		assert type <= type
		assert type >= _Deferred { type }
	end

	assert _Union(String, Integer) >= _Union(Integer, String)
	assert _Union(String, Integer, nil) >= nilable
	assert nilable >= _Union(String, nil)
	assert tagged >= _Union(String, Integer)
	assert _Union(String, Integer) >= tagged
	assert result >= _Union(Literal::Success(String), Literal::Failure(Integer))
	assert nilable <= _Union(String, nil)

	refute _Union(String, Integer) <= String
	refute nilable >= _Union(String, Integer)
	refute tagged <= String

	matcher = Class.new(BasicObject) { def ===(_value) = true }.new
	refute _TaggedUnion(string: String, any: matcher) <= Object
end
