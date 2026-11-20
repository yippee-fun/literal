# frozen_string_literal: true

class DataTest < Quickdraw::Test
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

	test "from_props resolves omitted optional properties to Literal::Undefined" do
		gap = Class.new(Literal::Data) do
			prop :a, _Optional(String)
			prop? :b, String
		end

		instance = gap.from_props({})

		assert_equal(instance.a, Literal::Undefined)
		assert_equal(instance.b, Literal::Undefined)
		assert_equal(gap.from_props(a: "first", b: "second").to_h, { a: "first", b: "second" })
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

	test "from_pack ignores attributes for properties that have been removed" do
		payload = Person.new(name: "John").as_pack
		payload[1][:removed] = true

		person = Person.from_pack(payload)

		assert_equal(person.name, "John")
		assert_equal(person.instance_variable_defined?(:@removed), false)
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

	test "private and protected readers leave equality and hash public" do
		[:private, :protected].each do |visibility|
			data = Class.new(Literal::Data) { prop :x, Integer, reader: visibility }
			struct = Class.new(Literal::Struct) do
				prop :x, Integer, reader: visibility
				check(:x, "must be positive") { |x:| x > 0 }
			end

			[data, struct].each do |shape|
				assert_equal(shape.new(x: 1), shape.new(x: 1))
				assert_equal(shape.new(x: 1).eql?(shape.new(x: 1)), true)
				assert_equal(shape.new(x: 1).hash, shape.new(x: 1).hash)
			end
		end
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

	test "define block" do
		Rect = Literal::Data.define(w: Integer, h: Integer) do
			prop :filled, _Boolean, default: false, predicate: :public

			def area = @w * @h
		end

		rect = Rect[w: 5, h: 4, filled: true]

		assert_equal(rect.area, 20)
		assert rect.filled?
	end

	test "define block runs with the new class as self" do
		receiver = nil
		klass = Literal::Data.define(name: String) { receiver = self }

		assert_same(receiver, klass)
		assert_equal(klass.superclass, Literal::Data)
	end

	test "define block receives the new class, like Ruby's Data.define" do
		yielded = nil
		klass = Literal::Data.define(name: String) { |it| yielded = it }

		assert_same(yielded, klass)
	end

	test "define block can define instance and class methods" do
		klass = Literal::Data.define(first: String, last: String) do
			def self.anonymous = new(first: "Jane", last: "Doe")

			def full_name = "#{first} #{last}"
		end

		assert_equal(klass.new(first: "John", last: "Smith").full_name, "John Smith")
		assert_equal(klass.anonymous.full_name, "Jane Doe")
	end

	test "define block props are type checked and part of the value" do
		klass = Literal::Data.define(name: String) do
			prop :age, Integer
		end

		a = klass.new(name: "John", age: 30)

		assert_equal(a.to_h, { name: "John", age: 30 })
		assert_equal(a, klass.new(name: "John", age: 30))
		refute_equal(a, klass.new(name: "John", age: 31))
		assert_equal(a.frozen?, true)
		assert_raises(Literal::TypeError) { klass.new(name: "John", age: "30") }
		assert_raises(ArgumentError) { klass.new(name: "John") }
	end

	test "define block can add positional props alongside keyword props" do
		klass = Literal::Data.define(name: String) do
			prop :id, Integer, :positional
			prop :tags, _Array(String), :*
		end

		instance = klass.new(1, "a", "b", name: "John")

		assert_equal(instance.to_h, { id: 1, tags: ["a", "b"], name: "John" })
		assert_equal(klass.from_props(instance.to_h), instance)
	end

	test "define block can build instances after declaring props" do
		klass = Literal::Data.define(x: Integer) do
			prop :y, Integer, default: 0

			const_set(:ORIGIN, new(x: 0))
		end

		assert_equal(klass::ORIGIN.to_h, { x: 0, y: 0 })
	end

	test "define block cannot add props after building an instance" do
		error = assert_raises(Literal::ArgumentError) do
			Literal::Data.define(x: Integer) do
				new(x: 0)
				prop :y, Integer
			end
		end

		assert error.message.include?("already has instances")
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

	test "slices can be built from an instance of the original" do
		original = SliceExample.new(name: "John", id: 1, age: 30)
		slice = SliceExample.slice(:id, :name).from(original)

		assert_equal slice.to_h, { id: 1, name: "John" }
		assert_equal slice.frozen?, true
	end

	test "from applies defaults for properties the source doesn't have" do
		source = Class.new(Literal::Data) do
			prop :name, String
		end

		instance = SliceExample.slice(:name, :age).from(source.new(name: "John"))

		assert_equal instance.name, "John"
		assert_equal instance.age, 0
	end

	test "from raises for missing required properties" do
		source = Class.new(Literal::Data) do
			prop :name, String
		end

		error = assert_raises(Literal::ArgumentError) do
			SliceExample.slice(:name, :id).from(source.new(name: "John"))
		end

		assert error.message.include?("Missing property :id")
	end

	test "from type checks matching properties" do
		source = Class.new(Literal::Data) do
			prop :name, _Nilable(String)
		end

		assert_raises(Literal::TypeError) do
			SliceExample.slice(:name).from(source.new(name: nil))
		end
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

	test "indexed access names the invalid key's class" do
		error = assert_raises(TypeError) { Person.new(name: "John")[0] }

		assert_equal error.message, "expected a string or symbol, got Integer"
	end

	test "indexed access reads the stored value whatever methods the object has" do
		klass = Class.new(Literal::Data) do
			prop :hash, Integer, reader: false
			prop :class, String, reader: false
			prop :y, Integer, reader: false
		end

		instance = klass.new(hash: 1, class: "c", y: 2)

		assert_equal [instance[:hash], instance[:class], instance[:y]], [1, "c", 2]
	end

	test "indexed access reads the stored value when a reader shadows instance_variable_get" do
		klass = Class.new(Literal::Data) do
			prop :instance_variable_get, String
		end

		assert_equal klass.new(instance_variable_get: "a")[:instance_variable_get], "a"
	end

	test "eql? compares values with eql?, agreeing with hash" do
		klass = Class.new(Literal::Data) { prop :n, Numeric }

		assert_equal klass.new(n: 1), klass.new(n: 1.0)
		assert_equal klass.new(n: 1).eql?(klass.new(n: 1.0)), false
		assert_equal klass.new(n: 1).eql?(klass.new(n: 1)), true
		assert_equal({ klass.new(n: 1) => true }.key?(klass.new(n: 1.0)), false)
	end

	test "copies stay frozen" do
		person = Person.new(name: "John")

		assert person.dup.frozen?
		assert person.clone.frozen?
		assert person.clone(freeze: false).frozen?
		assert_equal person.dup, person
	end

	class DataWithoutEql
		undef_method :eql?
	end

	class DataPrivatelyComparable
		def initialize(key) = @key = key

		attr_reader :key

		private def eql?(other) = DataPrivatelyComparable === other && @key == other.key
		private def hash = @key.hash
	end

	test "eql? and hash reach values without a public eql? or hash" do
		basic = BasicObject.new
		without_eql = DataWithoutEql.new
		any = Class.new(Literal::Data) { prop :value, BasicObject }
		typed = Class.new(Literal::Data) { prop :value, DataWithoutEql }
		private_eql = Class.new(Literal::Data) { prop :value, DataPrivatelyComparable }

		assert_equal any.new(value: basic), any.new(value: basic)
		assert_equal any.new(value: basic).eql?(any.new(value: basic)), true
		assert_equal any.new(value: basic).eql?(any.new(value: BasicObject.new)), false
		assert_equal any.new(value: basic).hash, any.new(value: basic).hash
		assert_equal any.new(value: without_eql).eql?(any.new(value: without_eql)), true
		assert_equal typed.new(value: without_eql).eql?(typed.new(value: without_eql)), true
		assert_equal typed.new(value: without_eql).eql?(typed.new(value: DataWithoutEql.new)), false
		assert_equal private_eql.new(value: DataPrivatelyComparable.new(1)).eql?(private_eql.new(value: DataPrivatelyComparable.new(1))), true
		assert_equal private_eql.new(value: DataPrivatelyComparable.new(1)).hash, private_eql.new(value: DataPrivatelyComparable.new(1)).hash
		assert_equal any.new(value: DataPrivatelyComparable.new(1)).eql?(any.new(value: DataPrivatelyComparable.new(1))), true
		assert_equal any.new(value: DataPrivatelyComparable.new(1)).hash, any.new(value: DataPrivatelyComparable.new(1)).hash
	end

	class WithExample < Literal::Data
		prop :x, Integer, :positional
		prop :label, String
		prop :note, _Nilable(String)

		check(:label, "must not be blank") { |label:| !label.empty? }
	end

	test "with returns a copy with the given properties replaced" do
		original = WithExample.new(1, label: "home", note: "hi")
		copy = original.with(x: 2, note: nil)

		assert_equal copy, WithExample.new(2, label: "home", note: nil)
		assert_equal original, WithExample.new(1, label: "home", note: "hi")
		assert copy.frozen?
	end

	test "with and no arguments returns self" do
		original = WithExample.new(1, label: "home")

		assert_same original, original.with
	end

	test "with type checks the new values" do
		original = WithExample.new(1, label: "home")

		assert_raises(Literal::TypeError) { original.with(x: "2") }
	end

	test "with runs the checks" do
		original = WithExample.new(1, label: "home")

		assert_raises(Literal::CheckError) { original.with(label: "") }
	end

	test "with raises for unknown attributes" do
		original = WithExample.new(1, label: "home")

		assert_raises(NameError) { original.with(nope: 1) }
	end

	test "with seals the new values" do
		sealed = Class.new(Literal::Data) do
			prop :name, String, &Literal::Coercions::Immutable
		end

		copy = sealed.new(name: "a").with(name: +"b")

		assert copy.name.frozen?
	end

	test "with coerces the new values before sealing them" do
		coerced = Class.new(Literal::Data) do
			prop :id, Integer do |it|
				Integer(it)
			end

			prop :name, String, &(Literal::Coercion(&:strip) >> Literal::Coercions::Immutable)
		end

		copy = coerced.new(id: 1, name: "a").with(id: "2", name: +" b ")

		assert_equal 2, copy.id
		assert_equal "b", copy.name
		assert copy.name.frozen?
	end

	test "with leaves unchanged values alone" do
		calls = 0

		counting = Class.new(Literal::Data) do
			prop :id, Integer do |it|
				calls += 1
				Integer(it)
			end

			prop :label, String
		end

		original = counting.new(id: "1", label: "a")
		copy = original.with(label: "b")

		assert_equal 1, calls
		assert_equal 1, copy.id
	end

	test "with runs after_initialize before freezing the copy" do
		derived = Class.new(Literal::Data) do
			prop :first, String
			prop :last, String

			attr_reader :full

			def after_initialize
				@full = "#{@first} #{@last}"
			end
		end

		copy = derived.new(first: "Ada", last: "Byron").with(last: "Lovelace")

		assert_equal "Ada Lovelace", copy.full
		assert copy.frozen?
	end

	test "with runs checks against the finished copy" do
		checked = Class.new(Literal::Data) do
			prop :n, Integer

			attr_reader :double

			def after_initialize
				@double = @n * 2
			end

			check(:n, "double must be under 10") { |n:| n * 2 < 10 }
		end

		assert_raises(Literal::CheckError) { checked.new(n: 1).with(n: 5) }
	end

	test "with copies stored members regardless of a custom to_h" do
		custom = Class.new(Literal::Data) do
			prop :id, Integer
			prop :secret, String

			def to_h
				{ "ID" => @id, "type" => "custom" }
			end
		end

		copy = custom.new(id: 1, secret: "s").with(id: 2)

		assert_equal 2, copy.id
		assert_equal "s", copy.secret
	end

	test "with on a subclass includes inherited and added properties" do
		parent = Class.new(Literal::Data) do
			prop :a, Integer
		end

		child = Class.new(parent) do
			prop :b, String
		end

		copy = child.new(a: 1, b: "x").with(b: "y")

		assert_equal child.new(a: 1, b: "y"), copy
		assert_raises(Literal::TypeError) { child.new(a: 1, b: "x").with(a: "1") }
	end

	test "with on a shape without properties" do
		empty = Empty.new

		assert_same empty, empty.with
		assert_raises(NameError) { empty.with(a: 1) }
	end

	test "with coerces against the copy, after its earlier properties" do
		prefixed = Class.new(Literal::Data) do
			prop :prefix, String
			prop :name, String do |it|
				"#{@prefix}-#{it}"
			end
		end

		copy = prefixed.new(prefix: "old", name: "x").with(prefix: "new", name: "y")

		assert_equal "new-y", copy.name
	end

	test "with resolves the default for an undefined value" do
		defaulted = Class.new(Literal::Data) do
			prop :count, Integer, default: 0
		end

		copy = defaulted.new(count: 1).with(count: Literal::Undefined)

		assert_equal 0, copy.count
	end

	test "with runs checks across changed and carried-over properties" do
		range = Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer

			check(:max, "must be at least %{min}") { |max:, min:| max >= min }
		end

		original = range.new(min: 1, max: 5)

		assert_raises(Literal::CheckError) { original.with(min: 6) }
		assert_raises(Literal::CheckError) { original.with(max: 0) }
		assert_equal range.new(min: 6, max: 7), original.with(min: 6, max: 7)
	end

	test "a reader named with is refused, but the property can be replaced" do
		[[], [[:a, Integer]]].each do |before|
			error = assert_raises(Literal::ArgumentError) do
				Class.new(Literal::Data) do
					before.each { |name, type| prop name, type }
					prop :with, String
				end
			end

			assert error.message.include?("reader: false")
		end

		named = Class.new(Literal::Data) do
			prop :a, Integer
			prop :with, String, reader: false
		end

		copy = named.new(a: 1, with: "x").with(with: "y")

		assert_equal copy[:with], "y"
		assert_equal copy.a, 1
	end

	test "with doesn't call methods a property can replace" do
		shadowing = Class.new(Literal::Data) do
			prop :class, String
			prop :freeze, String
			prop :raise, String
			prop :instance_exec, String
			prop :changes, String
			prop :shape, String
			prop :copy, String
			prop :__property__, String
			prop :v0, String

			check(:class, "must not be empty") { |class:| !binding.local_variable_get(:class).empty? }
		end

		values = %i[class freeze raise instance_exec changes shape copy __property__ v0].to_h { |name| [name, name.name] }
		copy = shadowing.new(**values).with(class: "b", v0: "w")

		assert_equal copy.to_h, values.merge(class: "b", v0: "w")
		assert copy.frozen?
		assert_raises(Literal::CheckError) { copy.with(class: "") }
		assert_raises(Literal::TypeError) { copy.with(class: 1) }
		assert_raises(NameError) { copy.with(nope: 1) }
	end

	test "with handles keyword-named, positional and block properties" do
		callback = -> {}
		other = -> {}

		klass = Class.new(Literal::Data) do
			prop :begin, Integer, :positional
			prop :end, Integer
			prop :block, Proc, :&
		end

		copy = klass.new(1, end: 2, &callback).with(end: 3, block: other)

		assert_equal copy[:begin], 1
		assert_equal copy[:end], 3
		assert_same copy.block, other
	end

	test "with is generated in full before the first instance" do
		klass = Class.new(Literal::Data) do
			prop :a, Integer
			prop :b, String
			prop :c, Integer, default: 0

			@copy = from_props(a: 1, b: "x", c: 2).with(b: "y")
		end

		assert_equal klass.instance_variable_get(:@copy).to_h, { a: 1, b: "y", c: 2 }
	end

	test "with unsets an optional property, and sets it" do
		klass = Class.new(Literal::Data) do
			prop? :nickname, String, predicate: :public
			prop? :tags, _Array(String), &Literal::Coercions::Immutable
			prop? :code, Integer do |it|
				Integer(it)
			end
		end

		original = klass.new(nickname: "Al", tags: ["a"], code: "1")
		unset = original.with(nickname: Literal::Undefined, tags: Literal::Undefined, code: Literal::Undefined)

		assert_equal unset.to_h, { nickname: Literal::Undefined, tags: Literal::Undefined, code: Literal::Undefined }
		assert_equal unset.nickname?, false
		assert_equal unset, klass.new

		set = unset.with(nickname: "Bo", tags: ["t"], code: "2")

		assert_equal set.to_h, { nickname: "Bo", tags: ["t"], code: 2 }
		assert set.tags.frozen?
		assert_equal set.nickname?, true
	end

	test "with resolves Proc defaults against the copy" do
		klass = Class.new(Literal::Data) do
			prop :first, String
			prop :greeting, String, default: -> { "Hello #{@first}" }
		end

		copy = klass.new(first: "Ada").with(first: "Grace", greeting: Literal::Undefined)

		assert_equal copy.greeting, "Hello Grace"
	end

	test "with resolves a block default on nil and takes splats as given, as new does" do
		klass = Class.new(Literal::Data) do
			prop :rest, _Array(Integer), :*
			prop :options, _Hash(Symbol, Integer), :**
			prop :block, Proc, :&, default: -> { -> { :default } }
		end

		original = klass.new(1, a: 1) { :given }

		assert_equal original.with(block: nil).block.call, :default
		assert_equal original.with(rest: [], options: {}).to_h.slice(:rest, :options), klass.new.to_h.slice(:rest, :options)
		assert_raises(Literal::TypeError) { original.with(block: Literal::Undefined) }
		assert_raises(Literal::TypeError) { original.with(rest: Literal::Undefined) }
		assert_raises(Literal::TypeError) { original.with(options: Literal::Undefined) }
	end

	test "with type checks carried-over values" do
		klass = Class.new(Literal::Data) do
			prop :ids, _Array(Integer)
			prop :n, Integer
		end

		ids = [1]
		original = klass.new(ids:, n: 1)
		ids << "2"

		assert_raises(Literal::TypeError) { original.with(n: 2) }
	end

	test "with reports errors from its caller" do
		original = WithExample.new(1, label: "home")
		type_error = assert_raises(Literal::TypeError) { original.with(x: "2") }
		check_error = assert_raises(Literal::CheckError) { original.with(label: "") }

		assert type_error.message.include?("#with (from #{type_error.backtrace[1]})")
		assert type_error.backtrace.first.include?("data.test.rb")
		assert check_error.backtrace.first.include?("data.test.rb")
	end

	test "with keeps the backtrace of a type error raised by after_initialize" do
		inner = Class.new(Literal::Data) { prop :n, Integer }
		inner.new(n: 1)
		line = nil

		outer = Class.new(Literal::Data) do
			prop :n, Integer

			define_method(:after_initialize) do
				line = __LINE__ + 1
				inner.new(n: "bad") if @n == 2
			end
		end

		error = assert_raises(Literal::TypeError) { outer.new(n: 1).with(n: 2) }

		assert error.backtrace.first.include?("data.test.rb:#{line}:")
	end

	test "with is generated where Object has no with" do
		assert system(
			RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-r", "literal",
			"-e", <<~RUBY
				shape = Class.new(Literal::Data) { prop :a, Integer }
				exit !Object.method_defined?(:with) && shape.new(a: 1).with(a: 2).a == 2
			RUBY
		) do
			"Expected with to be generated without Object#with to alias."
		end
	end

	class ConstCircle < Literal::Data
		const :kind, "circle"
		prop :radius, Integer
	end

	# Marshal doesn't work with anonymous classes
	class ::RootConstPattern < Literal::Data
		const :pattern, /circle/
		const :tag, Module.new
	end

	test "a const matched by identity survives Marshal" do
		assert_equal Marshal.load(Marshal.dump(RootConstPattern.new)), RootConstPattern.new
	end

	test "consts appear in to_h and ==" do
		circle = ConstCircle.new(radius: 1)

		assert_equal circle.to_h, { radius: 1, kind: "circle" }
		assert_equal circle, ConstCircle.new(radius: 1)
	end

	test "from_props fills an omitted const and checks a given one" do
		assert_equal ConstCircle.from_props(radius: 1).kind, "circle"
		assert_equal ConstCircle.from_props(radius: 1, kind: "circle").kind, "circle"
		assert_raises(Literal::TypeError) { ConstCircle.from_props(radius: 1, kind: "square") }
	end

	test "with checks a given const and keeps it" do
		circle = ConstCircle.new(radius: 1)

		assert_equal circle.with(kind: "circle"), circle
		assert_raises(Literal::TypeError) { circle.with(kind: "square") }
	end

	test "a given const stores the declared value, not the given one" do
		kind = +"circle"
		circle = ConstCircle.new(radius: 1)

		assert ConstCircle.from_props(radius: 1, kind:).kind.equal?(circle.kind)
		assert circle.with(kind:).kind.equal?(circle.kind)
		assert Literal::Draft(ConstCircle).check({ radius: 1, kind: }).value!.kind.equal?(circle.kind)
		assert Integer === Class.new(Literal::Data) { const :sides, 1 }.from_props(sides: 1.0).sides
	end
end
