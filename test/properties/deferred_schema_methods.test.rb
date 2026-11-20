# frozen_string_literal: true

class PropertiesDeferredSchemaMethodsTest < Quickdraw::Test
	module CountsSchemaCompilations
		def schema_compilations
			@schema_compilations ||= 0
		end

		def __generate_literal_methods__(...)
			@schema_compilations = schema_compilations + 1
			super
		end
	end

	def counted(superclass = Object, &block)
		Class.new(superclass) do
			extend Literal::Properties unless Literal::Properties === self
			extend CountsSchemaCompilations

			class_exec(&block) if block
		end
	end

	test "the schema-wide methods compile once, on first use" do
		example = counted do
			prop :name, String
			prop :age, Integer, reader: :public
			prop :admin, _Boolean, default: false
		end

		assert_equal example.schema_compilations, 0

		example.new(name: "Joel", age: 30)
		example.new(name: "Jill", age: 31)

		assert_equal example.schema_compilations, 1
	end

	test "each property's own methods are defined immediately" do
		readers = nil

		counted do
			prop :name, String, reader: :public, writer: :public, predicate: :public
			readers = [method_defined?(:name), method_defined?(:name=), method_defined?(:name?)]
		end

		assert_equal readers, [true, true, true]
	end

	test "instances behave as they would with eager methods" do
		example = Class.new(Literal::Struct) do
			prop :name, String, :positional, reader: :public
			prop :age, Integer, reader: :public, writer: :public
			prop :tags, _Array(String), default: -> { [] }
			prop? :nickname, String
		end

		instance = example.new("Joel", age: 30)

		assert_equal instance.to_h.slice(:name, :age, :tags), { name: "Joel", age: 30, tags: [] }
		assert_equal instance.to_hash, instance.to_h
		assert_equal example.instance_method(:initialize).parameters.map(&:last), [:name, :age, :tags, :nickname]

		instance.age = 31
		assert_equal instance.age, 31

		assert_raises(Literal::TypeError) { example.new("Joel", age: "30") }
		assert_raises(ArgumentError) { example.new("Joel") }
	end

	test "an instance built part way through a body sees every prop declared so far, and closes the shape" do
		early = nil
		refused = nil

		example = counted do
			prop :name, String
			prop :age, Integer
			early = new(name: "Joel", age: 30)
			begin
				prop :email, _Nilable(String)
			rescue Literal::ArgumentError => error
				refused = error
			end
		end

		assert_equal early.to_h, { name: "Joel", age: 30 }
		assert refused.message.include?("because it already has instances")
		assert_equal example.literal_properties.map(&:name), [:name, :age]
	end

	test "a user-defined initializer that calls super reaches the generated one" do
		calls = 0
		early = nil

		counted do
			define_method(:initialize) do |**kwargs|
				calls += 1
				super(**kwargs)
			end

			prop :name, String, reader: :public
			early = new(name: "Joel")
		end

		assert_equal calls, 1
		assert_equal early.name, "Joel"
	end

	test "a check declared before first use compiles nothing extra" do
		example = counted do
			prop :min, Integer
			prop :max, Integer
			check(:max, "must be greater than %{min}") { |max:, min:| max > min }
		end

		assert_equal example.new(min: 1, max: 2).to_h, { min: 1, max: 2 }
		assert_raises(Literal::CheckError) { example.new(min: 2, max: 1) }
		assert_equal example.schema_compilations, 1
	end

	test "freezing compiles what is pending" do
		example = counted do
			prop :name, String
			freeze
		end

		assert_equal example.schema_compilations, 1
		assert_equal example.new(name: "Joel").to_h, { name: "Joel" }
	end

	test "a property named hash never displaces the generated hash" do
		example = Class.new(Literal::Struct) do
			prop :name, String
			prop :hash, String, reader: false
		end

		a = example.new(name: "Joel", hash: "abc")
		b = example.new(name: "Joel", hash: "abc")

		assert_equal({ a => 1 }[b], 1)
	end

	test "a subclass compiles independently of its parent" do
		parent = counted do
			prop :name, String
			prop :age, Integer
		end

		child = Class.new(parent) do
			prop :email, String
			prop :admin, _Boolean
		end

		assert_equal child.new(name: "Joel", age: 30, email: "joel@example.com", admin: true).to_h.keys, [:name, :age, :email, :admin]
		assert_equal parent.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
		assert_equal parent.schema_compilations, 1
		assert_equal child.schema_compilations, 1
	end

	test "a subclass without props, built part way through its parent's body, sees the parent's props" do
		child = nil
		instance = nil

		counted do
			prop :name, String
			child = Class.new(self)
			instance = child.new(name: "Joel")
		end

		assert_equal instance.to_h, { name: "Joel" }
	end

	test "Literal::Struct compiles hash and == once" do
		example = counted(Literal::Struct) do
			prop :name, String
			prop :age, Integer
		end

		a = example.new(name: "Joel", age: 30)
		b = example.new(name: "Joel", age: 30)
		c = example.new(name: "Joel", age: 31)

		assert_equal example.schema_compilations, 1
		assert_equal a, b
		assert a.eql?(b)
		assert_equal a.hash, b.hash
		refute a == c
		assert_equal({ a => 1 }[b], 1)

		a.age = 31
		assert_equal a, c
	end

	test "Literal::Struct instances loaded with from_props compare by every prop" do
		example = counted(Literal::Struct) do
			prop :name, String
		end

		a = example.from_props(name: "Joel")
		b = example.from_props(name: "Jill")

		refute a == b
		refute a.hash == b.hash
	end

	test "Literal::Data compiles once" do
		example = counted(Literal::Data) do
			prop :name, String
			prop :age, Integer
		end

		a = example.new(name: "Joel", age: 30)

		assert_equal example.schema_compilations, 1
		assert a.frozen?
		assert_equal a, example.new(name: "Joel", age: 30)
		assert_equal a.hash, example.new(name: "Joel", age: 30).hash
		assert_equal example.from_props(name: "Joel", age: 30), a
		assert_equal a.with(age: 31).age, 31
	end

	test "Literal::Data.define compiles once" do
		base = counted(Literal::Data)
		example = base.define(name: String, age: Integer, email: String)
		a = example.new(name: "Joel", age: 30, email: "joel@example.com")

		assert_equal example.schema_compilations, 1
		assert_equal a.to_h, { name: "Joel", age: 30, email: "joel@example.com" }
		assert_equal a, example.new(name: "Joel", age: 30, email: "joel@example.com")
		assert a.frozen?
	end

	test "slice compiles once" do
		base = counted(Literal::Data)

		origin = Class.new(base) do
			prop :name, String
			prop :age, Integer
			prop :email, String
		end

		projection = origin.slice(:name, :age)

		assert_equal projection.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
		assert_equal projection.schema_compilations, 1
	end

	class CountedColor < Literal::Enum(Integer)
		extend CountsSchemaCompilations

		prop :hex, String
		prop :warm, _Boolean, predicate: :public

		Red = new(1, hex: "#f00", warm: true)
		Blue = new(2, hex: "#00f", warm: false)
	end

	test "Literal::Enum compiles once while building its members" do
		assert_equal CountedColor.schema_compilations, 1
		assert_equal CountedColor::Red.hex, "#f00"
		assert_equal CountedColor::Red.to_h, { value: 1, hex: "#f00", warm: true }
		assert CountedColor::Red.warm?
	end

	test "Literal::Enum.defined finishes an anonymous enum" do
		example = Class.new(Literal::Enum(String)) do
			prop :label, String
			index :label, String

			const_set(:A, new("a", label: "A"))
		end

		refute example.frozen?

		example.__send__(:defined)

		assert example.frozen?
		assert_equal example.find_by(label: "A"), example["a"]

		example.__send__(:defined)
	end

	ENUM_INDEX_RUNS = []

	class EnumDefinedBeforeEnd < Literal::Enum(String)
		index :upcase, String do |member|
			ENUM_INDEX_RUNS << member
			member.value.upcase
		end

		A = new("a")

		defined
	end

	test "the end of a Literal::Enum body skips work that `defined` already did" do
		assert EnumDefinedBeforeEnd.frozen?
		assert_equal ENUM_INDEX_RUNS, [EnumDefinedBeforeEnd::A]
		assert_equal EnumDefinedBeforeEnd.find_by(upcase: "A"), EnumDefinedBeforeEnd::A
	end

	test "threads calling a schema-wide method for the first time generate it once" do
		entered = Queue.new
		release = Queue.new

		example = counted do
			prop :name, String
		end

		example.define_singleton_method(:__generate_literal_methods__) do |*args|
			entered << true
			release.pop
			super(*args)
		end

		first = Thread.new { example.new(name: "Joel").to_h }
		entered.pop
		second = Thread.new { example.new(name: "Jill").to_h }
		Thread.pass while second.alive? && second.status != "sleep"
		release << true

		assert_equal first.value, { name: "Joel" }
		assert_equal second.value, { name: "Jill" }
		assert_equal example.schema_compilations, 1
	end

	test "Literal::Enum.defined hands on to a hook defined further up" do
		reached = []

		Module.class_eval do
			private define_method(:defined) { reached << self }
		end

		example = Class.new(Literal::Enum(String))

		begin
			example.__send__(:defined)
		ensure
			Module.remove_method(:defined)
		end

		assert example.frozen?
		assert_equal reached, [example]
	end

	test "generating can define another shape" do
		inner = nil

		outer = Class.new(Literal::Struct) do
			# Asking the union whether it takes nil materializes the deferred member.
			prop :child, _Union(String, _Deferred {
				inner ||= Class.new(Literal::Struct) do
					prop :name, String
				end

				_Nilable(inner)
			})
		end

		assert_equal outer.new.to_h, { child: nil }
		assert_equal outer.new(child: inner.new(name: "Joel")).child.name, "Joel"
	end

	test "a reader named after a schema-wide method is refused" do
		assert_raises(Literal::ArgumentError) do
			Class.new { extend Literal::Properties }.class_exec { prop :to_h, String, reader: :public }
		end

		example = Class.new { extend Literal::Properties }.tap { |it| it.prop :to_h, String }
		assert_equal example.new(to_h: "x").to_h, { to_h: "x" }
	end

	test "a Literal::Enum frozen by hand is not mistaken for a finished one" do
		example = Class.new(Literal::Enum(String)) do
			freeze
		end

		assert_raises(ArgumentError) { example.__send__(:defined) }
	end

	test "slices and drafts judge a copied signature once it is whole" do
		parent = Class.new(Literal::Data) do
			prop :a, String, :positional
			prop :b, String, :positional
			prop :c, _Array(String), :*
		end

		child = Class.new(parent) do
			prop :b, String, :positional, default: "b"
			prop :a, String, :positional, default: "a"
			prop :d, Integer, default: 0
		end

		assert_equal child.slice(:a, :b, :c).new.to_h, { a: "a", b: "b", c: [] }
		assert_equal Literal::Draft(child).new.finalize.to_h, { a: "a", b: "b", c: [], d: 0 }
	end

	test "generating one shape's methods doesn't block another shape's" do
		other = Class.new(Literal::Struct) { prop :name, String }

		example = Class.new(Literal::Struct) do
			prop :name, _Union(String, _Predicate("built elsewhere") { |value|
				Thread.new { other.new(name: "Jill") }.join(5) && value.nil?
			})
		end

		assert_equal Thread.new { example.new.to_h }.join(10)&.value, { name: nil }
	end
end
