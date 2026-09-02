# frozen_string_literal: true

Example = Literal::Object

test "positional params are required by default" do
	example = Class.new(Example) do
		prop :example, String, :positional
	end

	assert_raises(ArgumentError) { example.new }
	refute_raises { example.new("Hello") }
end

test "keyword params are required by default" do
	example = Class.new(Example) do
		prop :example, String
	end

	assert_raises(ArgumentError) { example.new }
	refute_raises { example.new(example: "Hello") }
end

test "nilable positional params are optional" do
	example = Class.new(Example) do
		prop :example, _Nilable(String), :positional
	end

	refute_raises { example.new }
	refute_raises { example.new("Hello") }
end

test "nilable keyword params are optional" do
	example = Class.new(Example) do
		prop :example, _Nilable(String)
	end

	refute_raises { example.new }
	refute_raises { example.new(example: "Hello") }
end

test "properties can be redefined with a subtype of the inherited type" do
	parent = Class.new(Example) do
		prop :id, _Union(Integer, String)
	end

	example = Class.new(parent) do
		prop :id, Integer
	end

	refute_raises { example.new(id: 1) }
	assert_raises(Literal::TypeError) { example.new(id: "1") }
end

test "properties cannot be redefined with a type incompatible with the inherited type" do
	parent = Class.new(Example) do
		prop :name, String
	end

	error = assert_raises(Literal::ArgumentError) do
		Class.new(parent) do
			prop :name, Symbol
		end
	end

	assert error.message.include?("must be a subtype of the inherited type")
end

test "properties cannot be redefined with a different kind" do
	parent = Class.new(Example) do
		prop :name, String, :positional
	end

	error = assert_raises(Literal::ArgumentError) do
		Class.new(parent) do
			prop :name, String
		end
	end

	assert error.message.include?("must match the inherited kind :positional")
end

test "properties can be redefined to add a reader" do
	parent = Class.new(Example) do
		prop :name, String
	end

	example = Class.new(parent) do
		prop :name, String, reader: :public
	end

	assert_equal example.new(name: "John").name, "John"
end

test "properties cannot be redefined to remove or hide a reader" do
	parent = Class.new(Example) do
		prop :name, String, reader: :public
	end

	assert_raises(Literal::ArgumentError) do
		Class.new(parent) { prop :name, String }
	end

	error = assert_raises(Literal::ArgumentError) do
		Class.new(parent) { prop :name, String, reader: :private }
	end

	assert error.message.include?("must be at least as visible as the inherited reader")
end

test "properties with an inherited writer can be redefined with a narrower type" do
	parent = Class.new(Example) do
		prop :id, _Union(Integer, String), writer: :public
	end

	example = Class.new(parent) do
		prop :id, Integer, writer: :public, reader: :public
	end

	instance = example.new(id: 1)
	instance.id = 2

	assert_equal instance.id, 2

	# The narrowed writer rejects values the inherited writer accepted, failing
	# loudly at the assignment site.
	assert_raises(Literal::TypeError) { instance.id = "3" }
end

test "narrowed redefinitions can add a writer when the inherited property had none" do
	parent = Class.new(Example) do
		prop :id, _Union(Integer, String)
	end

	example = Class.new(parent) do
		prop :id, Integer, reader: :public, writer: :public
	end

	instance = example.new(id: 1)
	instance.id = 2

	assert_equal instance.id, 2
end

test "properties cannot be added after a descendant has inherited the schema" do
	parent = Class.new(Example) do
		prop :a, String
	end

	grandchild = Class.new(Class.new(parent))
	grandchild.literal_properties

	error = assert_raises(Literal::ArgumentError) do
		parent.class_eval do
			prop :b, String
		end
	end

	assert error.message.include?("already inherited its properties")
end

test "properties can be added while no descendant has inherited the schema" do
	parent = Class.new(Example) do
		prop :a, String
	end

	child = Class.new(parent)

	parent.class_eval do
		prop :b, String
	end

	instance = child.new(a: "1", b: "2")

	assert_equal instance.to_h, { a: "1", b: "2" }
end

test "frozen defaults are type checked when the property is defined" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Example) do
			prop :age, Integer, default: "0"
		end
	end

	assert error.message.include?("must match its type")
end

test "defaults that go through coercion are not checked at definition" do
	example = Class.new(Example) do
		prop :age, Integer, reader: :public, default: "0" do |value|
			Integer(value)
		end
	end

	assert_equal example.new.age, 0
end

test "proc defaults are not checked at definition" do
	example = Class.new(Example) do
		prop :age, Integer, reader: :public, default: -> { 18 }
	end

	assert_equal example.new.age, 18
end

test "properties can be redefined within the same class" do
	example = Class.new(Example) do
		prop :name, String
		prop :name, Symbol
	end

	refute_raises { example.new(name: :john) }
end

test "properties can be redefined when either type is deferred" do
	parent = Class.new(Example) do
		prop :value, _Deferred { Integer }
	end

	refute_raises do
		Class.new(parent) do
			prop :value, Integer
		end
	end
end

test "prop? accepts a description" do
	example = Class.new(Example) do
		prop? :example, String, description: "An optional example"
	end

	assert_equal example.literal_properties[:example].description, "An optional example"
end

test "positional splats are optional" do
	example = Class.new(Example) do
		prop :example, _Array(String), :*
	end

	refute_raises { example.new }
	refute_raises { example.new("Hello") }
	refute_raises { example.new("Hello", "World") }
	refute example.literal_properties[:example].required? { "Expected example to not be required" }
end

test "keyword splats are optional" do
	example = Class.new(Example) do
		prop :example, _Hash(Symbol, String), :**
	end

	refute_raises { example.new }
	refute_raises { example.new(example: "Hello") }
	refute_raises { example.new(example: "Hello", world: "World") }
	refute example.literal_properties[:example].required? { "Expected example to not be required" }
end

test "block params are required by default" do
	example = Class.new(Example) do
		prop :example, Proc, :&
	end

	assert_raises(Literal::TypeError) { example.new }
	refute_raises { example.new { "Hello" } }
end

test "nilable block params are optional" do
	example = Class.new(Example) do
		prop :example, _Nilable(Proc), :&
	end

	refute_raises { example.new }
	refute_raises { example.new { "Hello" } }
end

test "optional keyword params are optional" do
	example = Class.new(Example) do
		prop :example, _Optional(String), reader: :public
	end

	refute_raises { example.new }
	refute_raises { example.new(example: "Hello") }
	refute_raises { example.new(example: Literal::Undefined) }
	assert_raises(Literal::TypeError) { example.new(example: 1) }
	assert_equal example.new.example, Literal::Undefined
	refute example.literal_properties[:example].required? { "Expected example to not be required" }
end

test "optional positional params are optional" do
	example = Class.new(Example) do
		prop :example, _Optional(String), :positional, reader: :public
	end

	refute_raises { example.new }
	refute_raises { example.new("Hello") }
	assert_equal example.new.example, Literal::Undefined
	assert_equal example.new("Hello").example, "Hello"
end

test "_Optional and prop? produce equivalent properties" do
	bare = Class.new(Example) do
		prop :example, _Optional(String), reader: :public
	end

	sugar = Class.new(Example) do
		prop? :example, String, reader: :public
	end

	bare_property = bare.literal_properties[:example]
	sugar_property = sugar.literal_properties[:example]

	assert_equal bare_property.type, sugar_property.type
	assert_equal bare_property.optional?, sugar_property.optional?
	assert_equal bare_property.default, sugar_property.default
	assert_equal bare.new.example, sugar.new.example
end

test "optional properties nest with nilable in either order" do
	example = Class.new(Example) do
		prop :undefined_or_nil, _Optional(_Nilable(String)), reader: :public
		prop :nil_or_undefined, _Nilable(_Optional(String)), reader: :public
	end

	# Both spellings canonicalise to the same union, so both are omittable and
	# both distinguish an omitted value from an explicit nil.
	assert_equal(
		example.literal_properties[:undefined_or_nil].type,
		example.literal_properties[:nil_or_undefined].type,
	)

	assert_equal example.new.undefined_or_nil, Literal::Undefined
	assert_equal example.new.nil_or_undefined, Literal::Undefined
	assert_equal example.new(undefined_or_nil: nil, nil_or_undefined: nil).nil_or_undefined, nil
end

test "optional block params are still required" do
	# Ruby resolves an omitted block to nil, so a block param can never receive
	# Literal::Undefined and _Optional cannot make one omittable.
	example = Class.new(Example) do
		prop :example, _Optional(Proc), :&
	end

	assert_raises(Literal::TypeError) { example.new }
	assert example.literal_properties[:example].required? { "Expected example to be required" }
end

test "only a union containing Literal::Undefined is optional" do
	# Optionality is exact containment, not `===`. The sentinel is a truthy
	# object, so `_Truthy === Literal::Undefined` is true — but merely matching
	# the sentinel does not mean "omittable"; declaring it as a union member
	# does. A bare `_Union` spelling is the same shape `_Optional` builds.
	example = Class.new(Example) do
		prop :declared, _Union(String, Literal::Undefined), reader: :public
		prop :truthy, _Truthy
		prop :any, _Any
		prop :not_nil, _Not(nil)
	end

	# The sentinel matches these types, but matching is not containment.
	assert example.literal_properties[:truthy].type === Literal::Undefined
	assert example.literal_properties[:any].type === Literal::Undefined
	assert example.literal_properties[:not_nil].type === Literal::Undefined

	assert example.literal_properties[:declared].undefinable? { "Expected declared to be undefinable" }
	refute example.literal_properties[:truthy].optional? { "Expected truthy to be required" }
	refute example.literal_properties[:any].optional? { "Expected any to be required" }
	refute example.literal_properties[:not_nil].optional? { "Expected not_nil to be required" }

	assert_raises(ArgumentError) do
		example.new(truthy: true, any: 1)
	end

	instance = example.new(truthy: true, any: 1, not_nil: 1)

	assert_equal instance.declared, Literal::Undefined
end

test "the sentinel is an ordinary object, not a Module" do
	# Literal::Undefined used to be a module, which made `Module === Undefined`
	# true and silently turned Module-typed properties optional. As a plain
	# object it satisfies no type about the object model.
	refute Module === Literal::Undefined
	refute Class === Literal::Undefined

	example = Class.new(Example) do
		prop :a, Module
	end

	assert_raises(ArgumentError) { example.new }
	assert example.literal_properties[:a].required? { "Expected a to be required" }
end

test "a declared Literal::Undefined member takes precedence over nil" do
	# A type can accept both sentinels. `_Optional` declares Literal::Undefined
	# as a member, so an omitted value resolves to it and stays distinguishable
	# from an explicit nil. `_Nilable(_Truthy)` only accepts it incidentally, so
	# nil wins and the property behaves as it always has.
	example = Class.new(Example) do
		prop :declared, _Optional(_Nilable(String)), reader: :public
		prop :incidental, _Nilable(_Truthy), reader: :public
	end

	assert example.literal_properties[:declared].undefinable? { "Expected declared to be undefinable" }
	refute example.literal_properties[:incidental].undefinable? { "Expected incidental not to be undefinable" }

	assert_equal example.new.declared, Literal::Undefined
	assert_equal example.new.incidental, nil
	assert_equal example.new(declared: nil).declared, nil
end

class Person
	extend Literal::Properties

	prop :name, String, :positional, reader: :public
	prop :age, Integer, reader: :public
end

class Random
	extend Literal::Properties
	prop :begin, Integer, :positional, reader: :public
end

class WithDefaultBlock
	extend Literal::Properties
	prop :block, Proc, :&, reader: :public, default: -> { proc { "Hello" } }
end

class WithContextualDefault
	extend Literal::Properties
	prop :hello, String, reader: :private, default: "Hello"
	prop :world, String, reader: :private, default: "World"
	prop :combined, String, reader: :public, default: -> { "#{hello} #{world}" }
end

class WithNilableType
	extend Literal::Properties
	prop :name, Literal::Types::NilableType.new(String), :positional
end

class Empty
	extend Literal::Properties
end

test "empty initializer" do
	refute_raises { Empty.new }
end

test do
	person = Person.new("John", age: 30)

	assert_equal person.name, "John"
	assert_equal person.age, 30
end

test "initializer type check" do
	error = assert_raises(Literal::TypeError) { Person.new(1, age: "Joel") }

	assert_equal error.message, <<~ERROR
  Type mismatch

  #{Person}#initialize (from #{error.backtrace[1]})
    name
      Expected: String
      Actual (Integer): 1
ERROR
end

test "initializer keyword check" do
	random = Random.new(1)

	assert_equal random.begin, 1
end

test "default block" do
	object = WithDefaultBlock.new
	assert_equal object.block.call, "Hello"

	object = WithDefaultBlock.new { "World" }
	assert_equal object.block.call, "World"
end

test "default value (as a proc) executes in the context of the receiver" do
	object = WithContextualDefault.new
	assert_equal object.combined, "Hello World"
end

test "properties are enumerable" do
	props = Person.literal_properties
	assert_equal props.size, 2
	assert_equal props.map(&:name), [:name, :age]

	props = Empty.literal_properties
	assert_equal props.size, 0
end

test "introspection" do
	prop1, prop2 = *Person.literal_properties

	assert_equal prop1.name, :name
	assert_equal prop1.type, String

	assert(prop1.positional?) { "Expected name to be kind :positional" }
	refute(prop1.keyword?) { "Expected name to not be kind :keyword" }
	refute(prop1.block?) { "Expected name to not be kind :&" }
	refute(prop1.splat?) { "Expected name to not be bind :*" }
	refute(prop1.double_splat?) { "Expected name to not be kind :**" }
	assert(prop1.required?) { "Expected name to be required" }
	refute(prop1.optional?) { "Expected name to not be optional" }

	assert_equal prop2.name, :age
	assert_equal prop2.type, Integer

	assert(prop2.keyword?) { "Expected age to be kind :keyword" }
	assert(prop2.required?) { "Expected age to be required" }

	props = WithDefaultBlock.literal_properties
	prop_block = props.first
	assert(prop_block.block?) { "Expected block to be kind :&" }
	assert(prop_block.optional?) { "Expected block to be optional" }

	props = WithNilableType.literal_properties
	prop_name = props.first
	assert(prop_name.optional?) { "Expected name to be optional" }
end

test "after initialize callback" do
	callback_called = false

	public_callback = Class.new do
		extend Literal::Properties

		prop :name, String

		define_method :after_initialize do
			callback_called = true
		end
	end

	public_callback.new(name: "John")

	assert callback_called

	callback_called = false

	protected_callback = Class.new do
		extend Literal::Properties

		prop :name, String

		define_method :after_initialize do
			callback_called = true
		end

		protected :after_initialize
	end

	protected_callback.new(name: "John")

	assert callback_called

	callback_called = false

	private_callback = Class.new do
		extend Literal::Properties

		prop :name, String

		define_method :after_initialize do
			callback_called = true
		end

		private :after_initialize
	end

	private_callback.new(name: "John")

	assert callback_called

	callback_called = false

	empty = Class.new do
		extend Literal::Properties

		define_method :after_initialize do
			callback_called = true
		end
	end

	empty.new

	assert callback_called
end

class Friend < Person
	prop :age, _Integer(18..), reader: :public
end

test "inheritance" do
	friend = Friend.new("John", age: 30)

	assert_equal friend.name, "John"
	assert_equal friend.age, 30

	assert_raises(Literal::TypeError) { Friend.new("John", age: 17) }
end

class WithPredicate
	extend Literal::Properties

	prop :enabled, _Boolean, predicate: :public
end

test "predicates" do
	enabled = WithPredicate.new(enabled: true)
	disabled = WithPredicate.new(enabled: false)

	assert_equal enabled.enabled?, true
	assert_equal disabled.enabled?, false
end

class WithOptionalPredicate
	extend Literal::Properties

	prop? :name, String, predicate: :public
end

test "predicates are false when an optional property is unset" do
	assert_equal WithOptionalPredicate.new.name?, false
	assert_equal WithOptionalPredicate.new(name: "Joel").name?, true
end

class WithWriters < Example
	extend Literal::Properties

	prop :example, _Nilable(String), writer: :public
	prop :a, _Nilable(_Array(String)), writer: :public
end

test "writer type error" do
	instance = WithWriters.new

	error = assert_raises(Literal::TypeError) do
		instance.example = 0
	end

	assert_equal error.message, <<~ERROR
  Type mismatch

  #{WithWriters}#example=(value) (from #{error.backtrace[1]})
    Expected: _Nilable(String)
    Actual (Integer): 0
ERROR

	error = assert_raises(Literal::TypeError) do
		instance.a = [1]
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		#{WithWriters}#a=(value) (from #{error.backtrace[1]})
		    [0]
		      Expected: String
		      Actual (Integer): 1
ERROR
end

class Family
	extend Literal::Properties

	prop :members, _Array(_Map(person: Person, role: Symbol)), :positional, reader: :public
	prop :last_reunion_year, _Nilable(Integer)
end

test "nested properties raise in initializer" do
	error = assert_raises(Literal::TypeError) do
		Family.new(
			[
				{
					person: Person.new("Json", age: 1),
					role: 1,
				},
				{
					person: Person.new("John", age: 30),
					role: "Father",
				},
				{
					1 => 2,
				},
			],
		)
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		#{Family}#initialize (from #{error.backtrace[1]})
		  members
		    [0]
		      [:role]
		        Expected: Symbol
		        Actual (Integer): 1
		    [1]
		      [:role]
		        Expected: Symbol
		        Actual (String): "Father"
		    [2]
		      [:person]
		        Expected: #{Person.inspect}
		        Actual (NilClass): nil
		      [:role]
		        Expected: Symbol
		        Actual (NilClass): nil
		ERROR

	error = assert_raises(Literal::TypeError) { Family.new([1]) }

	assert_equal error.message, <<~ERROR
		Type mismatch

		#{Family}#initialize (from #{error.backtrace[1]})
		  members
		    [0]
		      Expected: _Map(#{{ person: Person, role: Symbol }})
		      Actual (Integer): 1
ERROR

	error = assert_raises(Literal::TypeError) do
		Family.new([], last_reunion_year: :two_thousand)
	end

	assert_equal error.message, <<~ERROR
		Type mismatch

		#{Family}#initialize (from #{error.backtrace[1]})
		  last_reunion_year:
		    Expected: _Nilable(Integer)
		    Actual (Symbol): :two_thousand
		ERROR
end

test "nested properties succeed in initializer" do
	refute_raises do
		Family.new(
			[
				{
					person: Person.new("Json", age: 1),
					role: :son,
				},
				{
					person: Person.new("John", age: 30),
					role: :brother,
				},
			],
		)
	end

	refute_raises { Family.new([]) }
	refute_raises { Family.new([], last_reunion_year: 0) }
end

test "#to_h" do
	person = Person.new("John", age: 30)
	assert_equal person.to_h, { name: "John", age: 30 }

	empty = Empty.new
	assert_equal empty.to_h, {}
end

# Each prop re-emits the shared methods — the initializer, to_h, and a Data's
# hash and == — and a check re-emits the writers it reads. Every one of
# those redefinitions must be pre-aliased, or `-w` drowns the caller in
# "method redefined" warnings.
test "generated methods redefine without warnings" do
	warnings = []
	capturing = true
	interceptor = Module.new do
		define_method(:warn) do |message, **kwargs|
			capturing ? warnings << message : super(message, **kwargs)
		end
	end

	Warning.singleton_class.prepend(interceptor)
	verbose, $VERBOSE = $VERBOSE, true

	begin
		Class.new(Literal::Data) do
			prop :x, Integer, reader: :public
			prop :y, Integer, reader: :public
		end

		Class.new(Literal::Object) do
			prop :min, Integer, writer: :public, reader: :private, predicate: :public
			prop :max, Integer, writer: :public

			check(:max, "must be greater than %{min}") { |max:, min:| max > min }
		end
	ensure
		$VERBOSE = verbose
		capturing = false
	end

	assert_equal [], warnings.grep(/method redefined/)
end
