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
	prop :age, Float, reader: :public
end

test "inheritance" do
	friend = Friend.new("John", age: 30.5)

	assert_equal friend.name, "John"
	assert_equal friend.age, 30.5
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
