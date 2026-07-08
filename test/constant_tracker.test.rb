# frozen_string_literal: true

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
