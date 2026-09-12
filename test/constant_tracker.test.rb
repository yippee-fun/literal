# frozen_string_literal: true

require "weakref"

Object.const_set(:ConstantTrackerTopLevelObject, Object.new)
Object.const_set(:ConstantTrackerTest, Module.new)

ConstantTrackerTest.const_set(:TrackedObject, Object.new)
ConstantTrackerTest.const_set(:TrackedClass, Class.new)
ConstantTrackerTest.const_set(:TrackedModule, Module.new)
ConstantTrackerTest.const_set(:ResultType, Literal::Result(String, Symbol))

ConstantTrackerTest.const_set(:IntegerValue, 1)
ConstantTrackerTest.const_set(:FloatValue, 1.0)
ConstantTrackerTest.const_set(:SymbolValue, :constant_tracker_test_symbol)
ConstantTrackerTest.const_set(:NilValue, nil)
ConstantTrackerTest.const_set(:TrueValue, true)
ConstantTrackerTest.const_set(:FalseValue, false)

ConstantTrackerTest.const_set(:BasicObjectValue, BasicObject.new)
bad_hash_class = Class.new do
	def hash
		raise "boom"
	end
end
ConstantTrackerTest.const_set(:BadHashValue, bad_hash_class.new)

test "tracks top-level constants" do
	assert_equal Literal.const_ref(ConstantTrackerTopLevelObject).map(&:name), ["ConstantTrackerTopLevelObject"]
end

test "tracks object constants" do
	assert_equal Literal.const_ref(ConstantTrackerTest::TrackedObject).map(&:name), ["ConstantTrackerTest::TrackedObject"]
end

test "tracks class and module constants" do
	assert_equal Literal.const_ref(ConstantTrackerTest::TrackedClass).map(&:name), ["ConstantTrackerTest::TrackedClass"]
	assert_equal Literal.const_ref(ConstantTrackerTest::TrackedModule).map(&:name), ["ConstantTrackerTest::TrackedModule"]
end

test "literal types can find their constant name" do
	assert_equal ConstantTrackerTest::ResultType.name, "ConstantTrackerTest::ResultType"
end

test "does not track immediate values" do
	assert_equal Literal.const_ref(ConstantTrackerTest::IntegerValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::FloatValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::SymbolValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::NilValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::TrueValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::FalseValue), []
end

test "does not raise for objects that cannot be weak map keys" do
	assert_equal Literal.const_ref(ConstantTrackerTest::BasicObjectValue), []
	assert_equal Literal.const_ref(ConstantTrackerTest::BadHashValue), []
end

test "returns frozen empty references for untracked constants" do
	assert_equal Literal.const_ref(ConstantTrackerTest::IntegerValue), []
	assert Literal.const_ref(ConstantTrackerTest::IntegerValue).frozen?
end

test "does not retain removed classes or modules through their constants" do
	references = Thread.new do
		[Class, Module].flat_map do |type|
			3.times.map do
				Object.const_set(:ConstantTrackerReloadedOwner, type.new)
				ConstantTrackerReloadedOwner.const_set(:Payload, Object.new)
				reference = WeakRef.new(ConstantTrackerReloadedOwner)
				Object.__send__(:remove_const, :ConstantTrackerReloadedOwner)
				reference
			end
		end
	end.value

	3.times { GC.start }
	refute references.any?(&:weakref_alive?)
end

test "does not retain an owner when its constant value is still alive" do
	object = Object.new
	reference = Thread.new do
		owner = Module.new
		owner.const_set(:Payload, object)
		WeakRef.new(owner)
	end.value

	3.times { GC.start }
	refute reference.weakref_alive?
	assert_equal Literal.const_ref(object), []
end

test "preserves live aliases through garbage collection" do
	object = Object.new
	owner = Module.new
	owner.const_set(:First, object)
	owner.const_set(:Second, object)

	3.times { GC.start }
	references = Literal.const_ref(object)
	assert_equal references.map(&:owner), [owner, owner]
	assert_equal references.map(&:const), [:First, :Second]
end

test "drops removed and replaced constant references" do
	object = Object.new
	owner = Module.new
	owner.const_set(:Removed, object)
	owner.const_set(:Replaced, object)
	owner.const_set(:Kept, object)
	owner.__send__(:remove_const, :Removed)
	owner.__send__(:remove_const, :Replaced)
	owner.const_set(:Replaced, Object.new)

	assert_equal Literal.const_ref(object).map(&:const), [:Kept]
end

test "updates references when an anonymous owner receives a name" do
	owner = Module.new
	owner.const_set(:Payload, Object.new)
	reference = Literal.const_ref(owner::Payload).first
	assert_equal reference.name, "#<anonymous Module>::Payload"

	Object.const_set(:ConstantTrackerNamedOwner, owner)
	assert_equal reference.name, "ConstantTrackerNamedOwner::Payload"
ensure
	Object.__send__(:remove_const, :ConstantTrackerNamedOwner)
end

test "a saved reference does not keep its owner alive" do
	reference = Thread.new do
		owner = Module.new
		owner.const_set(:Payload, Object.new)
		Literal.const_ref(owner::Payload).first
	end.value

	3.times { GC.start }
	assert_equal reference.owner, nil
	assert_equal reference.name, nil
	assert_equal reference.to_s, ""
end

test "registering the same constant again does not accumulate references" do
	object = Object.new
	owner = Module.new
	owner.const_set(:Payload, object)

	3.times do
		owner.__send__(:remove_const, :Payload)
		owner.const_set(:Payload, object)
	end

	assert_equal Literal.const_ref(object).map(&:const), [:Payload]
end

test "discarding stale references does not trigger autoloads" do
	object = Object.new
	owner = Module.new
	owner.const_set(:Payload, object)
	owner.__send__(:remove_const, :Payload)
	owner.autoload(:Payload, "constant_tracker_should_not_load")

	assert_equal Literal.const_ref(object), []
	assert_equal owner.autoload?(:Payload), "constant_tracker_should_not_load"
end
