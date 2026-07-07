# frozen_string_literal: true

class Person < Literal::Data
	prop :name, String
end

class Empty < Literal::Data
end

class ReaderlessExample < Literal::Data
	prop :name, String, reader: false
end

class FromPropsExample < Literal::Data
	prop :x, Integer, :positional
	prop :y, Integer, :positional, default: 0
	prop :label, String
	prop :note, _Nilable(String)
end

class FromPropsSplats < Literal::Data
	prop :head, String, :positional
	prop :rest, _Array(String), :*
	prop :name, String
	prop :extras, _Hash(Symbol, String), :**
end

test "from_props builds instances regardless of property kind" do
	example = FromPropsExample.from_props(x: 1, y: 2, label: "home", note: "hi")

	assert_equal(example, FromPropsExample.new(1, 2, label: "home", note: "hi"))
end

test "from_props is the inverse of to_h" do
	example = FromPropsExample.new(1, 2, label: "home", note: nil)

	assert_equal(FromPropsExample.from_props(example.to_h), example)

	splats = FromPropsSplats.new("a", "b", "c", name: "x", other: "y")

	assert_equal(FromPropsSplats.from_props(splats.to_h), splats)
end

test "from_props applies defaults for omitted properties" do
	example = FromPropsExample.from_props(x: 1, label: "home")

	assert_equal(example.y, 0)
	assert_equal(example.note, nil)
end

test "from_props resolves omitted nilable, splat and double splat properties" do
	gap = Class.new(Literal::Data) do
		prop :a, _Nilable(String), :positional
		prop :b, String, :positional
	end

	instance = gap.from_props(b: "second")

	assert_equal(instance.a, nil)
	assert_equal(instance.b, "second")

	splats = FromPropsSplats.from_props(head: "a", name: "x")

	assert_equal(splats.rest, [])
	assert_equal(splats.extras, {})
end

test "from_props assigns block properties" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :callback, Proc, :&
	end

	callback = proc { 1 }
	instance = klass.from_props(name: "x", callback:)

	assert_equal(instance.callback, callback)
end

test "from_props raises NameError for unknown properties" do
	error = assert_raises(NameError) { FromPropsExample.from_props(x: 1, label: "home", wrong: true) }

	assert error.message.include?("unknown attribute: :wrong")
end

test "from_props type checks every value" do
	assert_raises(Literal::TypeError) { FromPropsExample.from_props(x: "one", label: "home") }
end

test "from_props raises for missing required properties" do
	error = assert_raises(Literal::ArgumentError) { FromPropsExample.from_props(label: "home") }

	assert error.message.include?("Missing property :x")
end

test "from_props takes property values without applying coercion" do
	klass = Class.new(Literal::Data) do
		prop :name, String do |value|
			"#{value}!"
		end
	end

	instance = klass.new(name: "Joel")

	assert_equal(instance.name, "Joel!")
	assert_equal(klass.from_props(instance.to_h).name, "Joel!")
end

test "from_props data objects are frozen" do
	assert_equal(FromPropsExample.from_props(x: 1, label: "home").frozen?, true)
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

test "define" do
	person_with_define = Literal::Data.define(name: String).new(name: "John")
	person = Person.new(name: "John")

	assert_equal(person_with_define.to_h, person.to_h)
end

test "initialize with [] method" do
	person_a = Person.new(name: "John")
	person_b = Person[name: "John"]

	assert_equal(person_a, person_b)
end

test "can be indexed" do
	person = Person.new(name: "John")
	assert_equal(person[:name], "John")
end

test "indexed access supports string keys" do
	person = Person.new(name: "John")
	assert_equal(person["name"], "John")
end

test "indexed access raises for unknown keys" do
	person = Person.new(name: "John")
	assert_raises(NameError) { person[:age] }
end

test "indexed access raises for invalid key types" do
	person = Person.new(name: "John")
	assert_raises(TypeError) { person[0] }
end
