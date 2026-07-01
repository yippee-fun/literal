#!/usr/bin/env ruby
# frozen_string_literal: true

# NOTE: This is not a quickdraw test becuase it needs to be run in a single thread.

require "literal"
require "set"

include Literal::Types

def count_allocations
	x = GC.stat(:total_allocated_objects)
	yield
	GC.stat(:total_allocated_objects) - x
end

def count_warm_allocations(&)
	count_allocations(&)
	count_allocations(&)
	count_allocations(&)
end

def assert_allocations(type, thing)
	count_warm_allocations do
		type === thing
	end.tap do |n|
		puts "#{n} allocations for #{type.inspect} === #{thing.inspect}"
	end
end

assert_allocations(_Any, "anything") => 0
assert_allocations(_Any, false) => 0

assert_allocations(_Array(String), []) => 0
assert_allocations(_Array(String), ["a", "b"]) => 0
assert_allocations(_Array(String), ["a", "b", 1]) => 0

assert_allocations(_Boolean, true) => 0
assert_allocations(_Boolean, false) => 0
assert_allocations(_Boolean, nil) => 0
assert_allocations(_Boolean, 1) => 0

assert_allocations(_Callable, -> {}) => 0
assert_allocations(_Callable, method(:puts)) => 0

assert_allocations(_Class(Enumerable), Array) => 0

assert_allocations(_Descendant(Enumerable), Array) => 0

assert_allocations(_Enumerable(String), []) => 0

assert_allocations(_Float(18.0..), 1.234) => 0

assert_allocations(_Frozen(String), "hello") => 0

assert_allocations(_Hash(String, Integer), { "a" => 1, "b" => 2 }) => 0

assert_allocations(_Integer(18..), 18) => 0

assert_allocations(_Interface(:to_s), "Hello") => 0

assert_allocations(_Intersection(Enumerable, Array), []) => 0

assert_allocations(_JSONData, { "a" => 1, "b" => [true, false, 0, 1.23, nil, { "a" => 1 }] }) => 0

assert_allocations(_Lambda, proc {}) => 0

assert_allocations(_Map(name: String, age: Integer), { name: "Joel", age: 30 }) => 0

assert_allocations(_Never, false) => 0

assert_allocations(_Nilable(String), nil) => 0

assert_allocations(_Not(Integer), 18) => 0

assert_allocations(_Procable, proc {}) => 0

assert_allocations(_Range(Integer), 0..10) => 0

assert_allocations(_Set(String), Set["a", "b", "c"]) => 0

assert_allocations(_String(length: 5..10), "Hello") => 0

assert_allocations(_Symbol(size: 5..10), :symbol) => 0

assert_allocations(_Truthy, true) => 0
assert_allocations(_Truthy, false) => 0

assert_allocations(_Tuple(String, Integer), ["a", 1]) => 0

assert_allocations(_Union(String, "Hello", "World"), "World") => 0

assert_allocations(_Void, nil) => 0
