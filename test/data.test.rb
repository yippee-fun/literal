# frozen_string_literal: true

class Person < Literal::Data
	prop :name, String
end

class Empty < Literal::Data
end

class ReaderlessExample < Literal::Data
	prop :name, String, reader: false
end

test "== comparison with readerless properties" do
	a = ReaderlessExample.new(name: "John")
	b = ReaderlessExample.new(name: "John")
	c = ReaderlessExample.new(name: "Bob")

	assert_equal(a, b)
	refute_equal(a, c)
end

test "properties have readers by default" do
	person = Person.new(name: "John")
	assert_equal(person.name, "John")
end

test "data objects are frozen" do
	person = Person.new(name: "John")
	assert_equal(person.frozen?, true)
end

test "immutable attributes are not duplicated" do
	name = "John"
	person = Person.new(name:)

	assert_equal(person.name.frozen?, true)
	assert_equal(person.name, name)
end

test "to_h" do
	person = Person.new(name: "John")
	assert_equal(person.to_h, { name: "John" })
end

test "can be deconstructed" do
	person = Person.new(name: "John")
	assert_equal(person.deconstruct, ["John"])
end

test "can be deconstructed with keys" do
	person = Person.new(name: "John")
	assert_equal(person.deconstruct_keys([:name]), { name: "John" })
end

test "can be implicitly coerced to Hash" do
	person = Person.new(name: "John")

	assert_equal({ last_name: "Doe" }.merge(person), { last_name: "Doe", name: "John" })
end

test "can be used as a hash key" do
	person = Person.new(name: "John")
	person2 = Person.new(name: "Bob")
	hash = { person => "John", person2 => "Bob" }
	assert_equal(hash[person], "John")
	assert_equal(hash[person2], "Bob")
	assert_equal(hash[Person.new(name: "John")], "John")
end

test "empty" do
	empty = Empty.new
	assert_equal(empty.to_h, {})

	other = Empty.new
	assert_equal(empty, other)
	assert_equal(empty.eql?(other), true)
	assert_equal(empty.hash, other.hash)

	other_empty = Class.new(Literal::Data).new
	assert_equal(empty != other_empty, true)
	assert_equal(empty.eql?(other_empty), false)
	assert_equal(empty.hash != other_empty.hash, true)
end

test "initialize with [] method" do
	person_a = Person.new(name: "John")
	person_b = Person[name: "John"]

	assert_equal(person_a, person_b)
end
