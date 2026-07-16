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

test "from_pack type checks the payload" do
	payload = Person.new(name: "John").as_pack
	payload[1][:name] = 42

	assert_raises(Literal::TypeError) { Person.from_pack(payload) }
end

test "from_pack raises NameError for unknown attributes" do
	payload = Person.new(name: "John").as_pack
	payload[1][:nope] = true

	error = assert_raises(NameError) { Person.from_pack(payload) }

	assert error.message.include?("unknown attribute: :nope")
end

test "from_pack applies defaults for missing properties" do
	payload = FromPropsExample.new(1, 2, label: "home", note: nil).as_pack
	payload[1].delete(:y)

	assert_equal(FromPropsExample.from_pack(payload).y, 0)
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

class SliceExample < Literal::Data
	prop :name, String
	prop :id, Integer
	prop :age, Integer, default: 0
end

test "slice returns a new data class with only the given properties" do
	slice = SliceExample.slice(:id, :name)
	user = slice.new(id: 1, name: "John")

	assert_equal(user.id, 1)
	assert_equal(user.name, "John")
	assert_equal(user.to_h, { id: 1, name: "John" })
	assert_equal(user.respond_to?(:age), false)
end

test "slices that drop properties do not subclass the sliced class" do
	slice = SliceExample.slice(:id)

	assert_equal(slice < Literal::Data, true)
	assert_equal(slice < SliceExample, nil)
end

test "slices subclass the deepest ancestor whose properties are all in the slice" do
	admin = Class.new(SliceExample) do
		prop :level, Integer
	end

	slice = admin.slice(:name, :id, :age)

	assert_equal(slice < SliceExample, true)
	assert_equal(slice < admin, nil)
	assert_equal(slice.new(name: "John", id: 1).to_h, { name: "John", id: 1, age: 0 })
end

test "slices subclass ancestors whose properties were narrowed by the sliced class" do
	parent = Class.new(Literal::Data) do
		prop :id, _Union(Integer, String)
	end

	child = Class.new(parent) do
		prop :id, Integer
		prop :name, String
	end

	slice = child.slice(:id)

	assert_equal(slice < parent, true)
	assert_equal(slice.new(id: 1).id, 1)
	assert_raises(Literal::TypeError) { slice.new(id: "1") }
end

test "slices carry over properties redefined by the sliced class" do
	parent = Class.new(Literal::Data) do
		prop :name, String
	end

	child = Class.new(parent) do
		prop :name, String, default: "Anon"
		prop :id, Integer
	end

	slice = child.slice(:name)

	assert_equal(slice < parent, true)
	assert_equal(slice.new.name, "Anon")
end

test "slices behave like an equivalent data class" do
	slice = SliceExample.slice(:id, :name)
	equivalent = Literal::Data.define(id: Integer, name: String)

	a = slice.new(id: 1, name: "John")
	b = slice.new(id: 1, name: "John")

	assert_equal(a, b)
	assert_equal(a.hash, b.hash)
	assert_equal(a.frozen?, true)
	assert_equal(a.to_h, equivalent.new(id: 1, name: "John").to_h)
end

test "slices type check their properties" do
	slice = SliceExample.slice(:id)

	assert_raises(Literal::TypeError) { slice.new(id: "1") }
end

test "slices carry over defaults" do
	slice = SliceExample.slice(:age)

	assert_equal(slice.new.age, 0)
end

test "slices carry over coercions" do
	klass = Class.new(Literal::Data) do
		prop :name, String do |value|
			"#{value}!"
		end

		prop :id, Integer
	end

	slice = klass.slice(:name)

	assert_equal(slice.new(name: "John").name, "John!")
end

test "slices preserve the original property order" do
	klass = Class.new(Literal::Data) do
		prop :a, String, :positional
		prop :b, String, :positional
	end

	slice = klass.slice(:b, :a)
	instance = slice.new("first", "second")

	assert_equal(instance.a, "first")
	assert_equal(instance.b, "second")
	assert_equal(instance.to_h, { a: "first", b: "second" })
end

test "slice raises NameError for unknown properties" do
	error = assert_raises(NameError) { SliceExample.slice(:id, :nope) }

	assert error.message.include?("unknown property: :nope")
end

test "instances of a subclass are never equal to instances of the parent" do
	parent = Class.new(Literal::Data) do
		prop :name, String
	end

	child = Class.new(parent)

	a = parent.new(name: "John")
	b = child.new(name: "John")

	refute_equal(a, b)
	refute_equal(b, a)
	assert_equal(a.eql?(b), false)
	assert_equal(a.hash == b.hash, false)
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
