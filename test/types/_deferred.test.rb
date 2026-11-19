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
