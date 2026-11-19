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

test "#==" do
	assert_equal _Union(:a, String), _Union(:a, String)

	refute_equal _Union(:a, String), _Union(:a, Integer)
	refute_equal _Union(:a, String), String
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

test "#reject" do
	assert_equal _Union(String, Literal::Undefined).reject { |type| type == Literal::Undefined }, String
	assert_equal _Union(String, Integer, Literal::Undefined).reject { |type| type == Literal::Undefined }.inspect, "_Union(String, Integer)"
	assert_equal _Union(String, Literal::Undefined).reject { |_type| true }, _Never
end

test "never members are removed" do
	assert_equal _Union(String, Integer, _Never).to_a, [String, Integer]
	assert_equal _Union(String, Integer, _Never).inspect, "_Union(String, Integer)"
	assert_equal _Union(String, _Union(Integer, _Never)).to_a, [String, Integer]

	assert_subtype _Never, _Union(String, Integer, _Never)
	refute _Union(String, Integer, _Never) === nil
end

test "a union of only never members is never" do
	assert_equal _Union(_Never), _Never
	assert_equal _Union(_Never, _Never), _Never
	assert_equal _Union(_Never, _Union(_Never)), _Never
end

test "a union containing any-nilable is any-nilable" do
	assert_equal _Union(String, _Any?), _Any?
	assert_equal _Union(String, _Nilable(_Any)), _Any?
	assert_equal _Union(_Any?, _Never), _Any?
end

test "a union does not absorb void" do
	assert_equal _Union(String, _Void).to_a, [String, _Void]
end

test "a union flattens nilable members" do
	assert_equal _Union(_Nilable(String), Integer).to_a, [nil, String, Integer]
	assert_equal _Union(_Nilable(String), _Nilable(Integer)).to_a, [nil, String, Integer]
	assert_equal _Union(_Nilable(_Union(String, Symbol))).to_a, [nil, String, Symbol]
end

test "flattening a member keeps its declared position" do
	# Order decides how JSON schemas list members and how resolve breaks ties,
	# so a flattened member takes the place of the one it came from.
	assert_equal _Union(_Nilable(String), Integer).literal_child_types.to_a, [String, Integer]
	assert_equal _Union(Integer, _Nilable(String)).literal_child_types.to_a, [Integer, String]
	assert_equal _Union(_Union(String, Symbol), Integer).literal_child_types.to_a, [String, Symbol, Integer]
	assert_equal _Union(Integer, _Union(String, Symbol)).literal_child_types.to_a, [Integer, String, Symbol]
end

test "a union of the same members is equal regardless of order" do
	# Order is behaviourally meaningful — resolve breaks ties by it — but it
	# does not distinguish one type from another.
	assert_equal _Union(String, Integer), _Union(Integer, String)
	assert_equal _Union(String, Integer, :a, :b), _Union(:b, Integer, :a, String)
	assert_equal _Optional(_Nilable(String)), _Nilable(_Optional(String))

	refute_equal _Union(String, Integer), _Union(String, Integer, Symbol)
	refute_equal _Union(String, Integer), _Union(String, Symbol)
	refute_equal _Union(String, :a), _Union(String, :b)
end

test "a union with a single member is that member" do
	assert_equal _Union(String), String
	assert_equal _Union(String, String), String
	assert_equal _Union(String, _Never), String
	assert_equal _Union(:a, _Union(:a)), :a
end

test "hierarchy" do
	assert_subtype _Union(:a), _Union(:a)
	assert_subtype _Union(:a, :b, :c), _Union(:a, :b, :c)
	assert_subtype _Union(:a, :b, :c), _Union(:a, :b, :c, :d)

	assert_subtype _Union(Integer), _Union(Numeric)
	assert_subtype Integer, _Union(Numeric)
	assert_subtype 1, _Union(Numeric)
	assert_subtype _Union(1, 2, 3), _Union(Numeric)

	# The literal 1 admits 1.0 (via ==), so it is not bounded by Integer.
	refute_subtype 1, _Union(Integer)
	refute_subtype _Union(1, 2, 3), _Union(Integer)
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

test "nil members cover nilable types" do
	immediate = _Union(Integer, Float, Symbol, nil, _Boolean)

	assert_subtype _Nilable(Integer), immediate
	assert_subtype _Falsy, immediate
	assert _Kind(immediate) === _Nilable(Integer)
	assert _Kind(immediate) === _Falsy
	assert _Kind(immediate) === NilClass
	assert _Kind(immediate) === TrueClass
	assert _Kind(immediate) === FalseClass
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

test "#resolve picks the most specific matching member" do
	parent = Class.new
	child = Class.new(parent)

	[_Union(parent, child), _Union(child, parent)].each do |type|
		assert_equal type.resolve(child.new), child
		assert_equal type.resolve(parent.new), parent
	end
end

test "#resolve breaks ties between incomparable members by declaration order" do
	both = Class.new { include Comparable, Enumerable }.new

	assert_equal _Union(Comparable, Enumerable).resolve(both), Comparable
	assert_equal _Union(Enumerable, Comparable).resolve(both), Enumerable
end

# Ties are judged among the matches alone: a subtype of `animal` that doesn't
# match can't push `animal` behind `robot`.
test "#resolve breaks ties by declaration order whatever else the union holds" do
	animal = Class.new
	robot = Module.new
	dog = Class.new(animal)
	type = _Union(animal, robot, dog)

	assert_equal type.resolve(Class.new(animal) { include robot }.new), animal
	assert_equal type.resolve(Class.new(dog) { include robot }.new), robot
	assert_equal type.resolve(dog.new), dog
end

test "#resolve matches primitives before types" do
	assert_equal _Union(Integer, 1).resolve(1), 1
	assert_equal _Union(Integer, 1).resolve(2), Integer
	assert_raises(Literal::ArgumentError) { _Union(Integer, 1).resolve("1") }
end

# A type is below another only if the latter says so, so the relation need not
# be transitive: here c is below b and b below a, but c is not below a.
test "#resolve picks a most specific member when subtyping is not transitive" do
	rung = Class.new do
		include Literal::Type

		def initialize(name, *below)
			@name = name
			@below = below
		end

		attr_reader :name

		def ===(value) = value.include?(@name)

		def >=(other, context: nil)
			equal?(other) || @below.include?(other)
		end
	end

	c = rung.new(:c)
	b = rung.new(:b, c)
	a = rung.new(:a, b)
	type = _Union(a, c, b)

	assert_equal type.resolve([:a, :b, :c]), c
	assert_equal type.resolve([:a, :c]), a
	assert_equal type.resolve([:a, :b]), b
	assert_equal type.resolve([:b, :c]), c
	assert_equal type.resolve([:a]), a
end

test "#resolve refuses members that are strict subtypes of one another in a cycle" do
	rung = Class.new do
		include Literal::Type

		def initialize = @below = []

		attr_reader :below

		def ===(value) = true

		def >=(other, context: nil)
			equal?(other) || @below.include?(other)
		end
	end

	a, b, c = rung.new, rung.new, rung.new
	a.below << b
	b.below << c
	c.below << a

	assert_raises(Literal::ArgumentError) { _Union(a, b, c).resolve(1) }
end

test "constructing a union does not materialize deferred members" do
	materialized = false
	deferred = _Deferred do
		materialized = true
		Integer
	end
	type = _Union(String, deferred)

	assert type === "a"
	refute materialized

	assert_equal type.resolve(1), deferred
	assert materialized
end

test "resolving a value does not materialize deferred members it doesn't match" do
	deferred = _Deferred { raise "materialized" }
	type = _Union(String, _Array(Integer), _Array(deferred))

	assert_equal type.resolve("a"), String
end

if defined?(Ractor)
	test "a union is Ractor-shareable and resolves once shared" do
		type = Ractor.make_shareable(_Union(String, Integer))

		assert Ractor.shareable?(type)
		assert_equal type.resolve(1), Integer
	end
end

test "a cyclic value re-entering a union through a proc member does not match" do
	node = _Union(nil, _Array(-> (value) { node === value }))
	array = []
	array << array

	refute node === array
	assert node === [nil, [nil]]
end

test "a value re-entering a union through a module with its own === does not match" do
	union = nil
	reentrant = Class.new { define_singleton_method(:===) { |value| union === value } }
	union = _Union(nil, reentrant)

	refute union === :x
end

test "building a union over shared subtrees visits each once" do
	tuple = Integer
	30.times { tuple = _Tuple(tuple, tuple) }

	refute _Union(nil, tuple) === 1
end

test "literal members match with ==, like bare literals" do
	union = _Union(1, "a", [1])

	assert 1 === 1.0
	assert union === 1.0
	assert union === 1r
	assert union === [1.0]
	assert union === +"a"

	refute union === 2.0
	refute union === "b"
end

test "#resolve finds the literal member a value equals" do
	union = _Union(1, "a", String)

	assert_same union.resolve(1.0), 1
	assert_equal union.resolve(1), 1
	assert_equal union.resolve("a"), "a"
	assert_equal union.resolve("b"), String
end

test "#resolve prefers a matching type to a literal the value is merely == to" do
	union = _Union(1, Float)

	assert_equal union.resolve(1.0), Float
	assert_equal union.resolve(1r), 1
end
