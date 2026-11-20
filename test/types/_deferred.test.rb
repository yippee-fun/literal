# frozen_string_literal: true

include Literal::Types

test "===" do
	recursive = _Hash(
		String,
		_Deferred { recursive }
	)

	assert recursive === {
		"a" => {
			"b" => {
				"c" => {
					"d" => {
						"e" => {
							"f" => {
								"g" => {},
							},
						},
					},
				},
			},
		},
	}

	refute recursive === {
		"a" => {
			"b" => { 1 => {} },
		},
	}
end

test "hirearchy" do
	assert_subtype Integer, _Deferred { Numeric }
	assert_subtype _Deferred { Integer }, _Deferred { Numeric }
end

test "hierarchy with recursive deferred union does not recurse forever" do
	recursive = _Union(Integer, _Nilable(_Deferred { recursive }))

	assert_subtype Integer, recursive
	refute_subtype Proc, recursive
	assert_equal false, Literal.subtype?(Proc, recursive)
end

test "subtype in-progress guard keeps parent lock" do
	recursive = _Union(Integer, _Nilable(_Deferred { recursive }))

	3.times do
		assert_equal false, Literal.subtype?(Proc, recursive)
	end
end

test "subtype handles deferred fresh-wrapper cycles" do
	recursive = _Deferred { _Nilable(recursive) }

	assert_equal false, Literal.subtype?(Proc, recursive)
end

test "a cyclic value re-entering the same deferred type does not match" do
	union = _Union(nil, _Array(_Deferred { union }))
	array = []
	array << array

	refute union === array
	assert union === [[], [nil]]
end

test "a cyclic value through a recursive tagged union does not match" do
	tagged = _TaggedUnion(leaf: Integer, branch: _Array(_Deferred { tagged }))
	array = [1]
	array << array

	refute tagged === array
	assert tagged === [1, [2, []]]
end

test "a cyclic value through a recursive hash does not match" do
	recursive = _Hash(String, _Deferred { recursive })
	hash = {}
	hash["self"] = hash

	refute recursive === hash
end

test "threads materializing at once all get the first published result" do
	started = Queue.new
	results = Queue.new
	deferred = _Deferred do
		started << true
		results.pop
	end

	first = Thread.new { deferred.materialize }
	started.pop
	second = Thread.new { deferred.materialize }
	Thread.pass while second.status == "run"
	results << Integer
	Thread.pass until first.status == false || second.status == false
	results << String

	assert_equal first.value, Integer
	assert_equal second.value, Integer
	assert_equal deferred.materialize, Integer
end

test "a deferred type that refers to itself materializes to itself on re-entry" do
	deferred = _Deferred { deferred.materialize }

	assert_equal deferred.materialize, deferred
end

# Waiting for another thread's materialization would deadlock here: the first
# thread's block needs a lock the second thread holds while materializing.
test "a thread materializing doesn't wait on another thread's block" do
	lock = Monitor.new
	entered = Queue.new
	locked = Queue.new
	go = Queue.new
	deferred = _Deferred do
		entered << true
		lock.synchronize { Integer }
	end

	holder = Thread.new do
		lock.synchronize do
			locked << true
			go.pop
			deferred.materialize
		end
	end
	locked.pop

	waiter = Thread.new { deferred.materialize }
	entered.pop
	Thread.pass while waiter.status == "run"
	go << true

	assert holder.join(5)
	assert waiter.join(5)
	assert_equal holder.value, Integer
	assert_equal waiter.value, Integer
ensure
	holder&.kill
	waiter&.kill
end

if defined?(Ractor)
	test "a materialized deferred type can be made Ractor-shareable" do
		block = Ractor.make_shareable(nil.instance_exec { proc { Integer } })
		deferred = _Deferred(&block)
		deferred.materialize

		assert Ractor.shareable?(Ractor.make_shareable(deferred))
	end
end

test "a prop typed by a bare deferred type is required, and declaring it materializes nothing" do
	materialized = 0

	keyword = Class.new(Literal::Data) do
		prop :a, _Deferred { materialized += 1; String }
	end

	positional = Class.new(Literal::Data) do
		prop :a, _Deferred { materialized += 1; String }, :positional
	end

	assert_equal materialized, 0
	assert keyword.literal_properties[:a].required?
	assert positional.literal_properties[:a].required?
	assert_equal materialized, 0

	error = assert_raises(ArgumentError) { keyword.new }
	# JRuby writes the keyword without its colon.
	assert(/\Amissing keyword: :?a\z/.match?(error.message))
	assert_raises(ArgumentError) { positional.new }

	error = assert_raises(Literal::ArgumentError) { keyword.from_props({}) }
	assert error.message.include?("Missing property :a")

	assert_equal keyword.new(a: "x").a, "x"
	assert_raises(Literal::TypeError) { keyword.new(a: nil) }
end

test "a deferred type takes nil through _Nilable outside it" do
	materialized = 0

	nilable = Class.new(Literal::Data) do
		prop :a, _Nilable(_Deferred { materialized += 1; String })
		prop :b, _Nilable(_Deferred { materialized += 1; String }), :positional
	end

	optional = Class.new(Literal::Data) do
		prop? :a, _Deferred { materialized += 1; String }
	end

	assert_equal materialized, 0
	assert_equal nilable.new.to_h, { a: nil, b: nil }
	assert_equal optional.new.to_h, { a: Literal::Undefined }
end

test "a deferred type is required even when it would take nil" do
	klass = Class.new(Literal::Data) do
		prop :a, _Deferred { _Nilable(String) }
	end

	assert_raises(ArgumentError) { klass.new }
	assert_equal klass.new(a: nil).a, nil
end

test "a deferred type that materializes to another deferred type is compared by what the chain ends in" do
	string = _Deferred { _Deferred { String } }
	boolean = _Deferred { _Deferred { _Union(true, false) } }

	assert_subtype string, String
	assert_subtype _Array(string), _Array(String)
	assert_subtype boolean, _Boolean
	refute_subtype string, Integer
end

test "a deferred chain checked against a union doesn't force members it doesn't need" do
	chain = _Deferred { _Deferred { _Union(String, Integer) } }

	assert_subtype chain, _Union(String, Integer, _Deferred { FutureType })
end

test "a deferred chain compared with itself or _Never stays unmaterialized" do
	chain = _Deferred { _Deferred { FutureType } }

	assert_subtype chain, chain
	assert_subtype _Never, chain
end

test "deferred alias cycles match nothing, like _Never" do
	b = nil
	a = _Deferred { b }
	b = _Deferred { a }
	itself = _Deferred { itself }

	refute a === 1
	refute itself === 1

	assert_subtype a, b
	assert_subtype b, a
	assert_subtype a, a
	assert_subtype a, itself
	assert_subtype itself, a
	assert_subtype a, String
	assert_subtype itself, String
	assert_subtype itself, _Never
	assert_subtype _Array(itself), _Array(Integer)

	refute_subtype String, a
	refute_subtype String, itself
	refute_subtype _Void, itself
end

test "a recursive union on the left is a subtype of what its other members fit" do
	node = _Deferred { _Union(String, node) }
	union = _Union(String, _Deferred { union })
	nilable = _Deferred { _Nilable(nilable) }

	refute node === 1
	assert node === "a"

	assert_subtype node, _Void
	assert_subtype node, String
	assert_subtype _Deferred { node }, _Void
	assert_subtype union, _Any
	assert_subtype union, String
	assert_subtype nilable, nil
	assert_subtype _Array(node), _Array(String)

	refute_subtype node, Integer
	refute_subtype union, Symbol
	refute_subtype nilable, String
end

test "a cycle that unfolds the right side proves nothing" do
	never = _Deferred { never }
	integers = _Deferred { _Union(Integer, integers) }
	node = _Deferred { _Union(String, node) }

	refute_subtype String, never
	refute_subtype String, integers
	refute_subtype node, never
	refute_subtype node, integers

	assert_subtype Integer, integers
	assert_subtype never, integers
end

test "recursive unions on both sides compare by their members" do
	strings = _Deferred { _Union(String, strings) }
	more_strings = _Deferred { _Union(more_strings, String) }
	numbers = _Deferred { _Union(Integer, Float, numbers) }

	assert_subtype strings, more_strings
	assert_subtype more_strings, strings
	refute_subtype numbers, strings
	refute_subtype strings, numbers
end

test "a recursive type under _Not swaps sides" do
	never = _Deferred { never }
	node = _Deferred { _Union(String, node) }

	assert_subtype _Not(String), _Not(never)
	assert_subtype _Not(String), _Not(node)
	assert_subtype _Not(node), _Not(String)

	refute_subtype _Not(never), _Not(String)
	refute_subtype _Not(Integer), _Not(node)
end

test "a type that refers to itself under _Not is not assumed through its cycle" do
	negated = _Deferred { _Not(negated) }
	either = _Deferred { _Union(either, _Not(either)) }
	other = nil
	mutual = _Deferred { _Not(other) }
	other = _Deferred { _Not(mutual) }

	assert negated === 1
	refute mutual === 1
	assert either === nil
	refute _Any === nil

	refute_subtype negated, mutual
	refute_subtype either, _Not(either)
	refute_subtype either, _Any
end

test "a type that refers to itself under _Not inside a container is still assumed" do
	guarded = _Deferred { _Union(String, guarded, _Array(_Not(guarded))) }
	later = _Deferred { _Union(later, _Array(_Deferred { LaterUndefinedType })) }

	assert_subtype guarded, _Union(String, Array)
	assert_subtype later, Array
end

test "a type that refers to itself under _Not through a property constraint is still assumed" do
	sized = _Deferred { _Union(sized, _Constraint(String, size: _Not(sized))) }

	assert_subtype sized, String
end

test "an assumption made in a failed branch doesn't block a branch that succeeds" do
	type = _Deferred { _Constraint(_Union(type, _Not(type)), String) }

	assert_subtype type, String
	assert_equal _Union(Object, type).resolve("s"), type
end

test "a refused cycle leaves the proof free to try another way" do
	type = _Deferred { _Constraint(type, String, _Not(type)) }
	hidden = _Deferred { _Constraint(hidden, String, _Deferred { _Not(hidden) }) }

	assert_subtype type, String
	assert_equal true, Literal.subtype?(hidden, String)
	assert_equal true, Literal.subtype?(hidden, String)
end

test "a deferred matcher that only answers === is walked without calling its methods" do
	matcher = BasicObject.new
	def matcher.===(value) = String === value
	leaf = _Deferred { matcher }
	type = _Deferred { _Constraint(leaf, type) }

	assert_subtype type, String
end

test "a failing recursive check doesn't force deferred members it doesn't need" do
	type = _Deferred { _Union(type, String, _Deferred { NeverDefinedType }) }

	refute_subtype type, Integer
end

test "a recursive type with a matcher that only answers === is still assumed" do
	matcher = BasicObject.new
	def matcher.===(value) = String === value
	type = _Deferred { _Union(type, _Constraint(String, _Not(matcher))) }

	assert_subtype type, String
end

test "a deferred alias of a deferred chain matches it without forcing the shared tail" do
	inner = _Deferred { _Deferred { FutureType } }
	type = _Deferred { inner }
	alias_type = _Deferred { type }

	assert_subtype type, alias_type
end
