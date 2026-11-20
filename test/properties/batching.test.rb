# frozen_string_literal: true

class PropertiesBatchingTest < Quickdraw::Test
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

	test "without a batch, every prop compiles the schema-wide methods" do
		example = counted do
			prop :name, String
			prop :age, Integer
		end

		assert_equal example.schema_compilations, 2
	end

	test "a batch compiles the schema-wide methods once" do
		example = counted do
			props do
				prop :name, String
				prop :age, Integer, reader: :public
				prop :admin, _Boolean, default: false
			end
		end

		assert_equal example.schema_compilations, 1
	end

	test "a batch defines each property's own methods immediately" do
		readers = nil

		counted do
			props do
				prop :name, String, reader: :public, writer: :public, predicate: :public
				readers = [method_defined?(:name), method_defined?(:name=), method_defined?(:name?)]
			end
		end

		assert_equal readers, [true, true, true]
	end

	test "an empty batch compiles nothing" do
		example = counted do
			begin_props
			commit_props
		end

		assert_equal example.schema_compilations, 0
		assert_equal example.new.to_h, {}
	end

	test "props requires a block" do
		assert_raises(Literal::ArgumentError) do
			counted { props }
		end
	end

	test "instances of a batched class behave like those of an unbatched one" do
		declarations = proc do
			prop :name, String, :positional, reader: :public
			prop :age, Integer, reader: :public, writer: :public
			prop :tags, _Array(String), default: -> { [] }
			prop? :nickname, String
		end

		unbatched = Class.new(Literal::Struct, &declarations)
		batched = Class.new(Literal::Struct) { props { class_exec(&declarations) } }

		a = unbatched.new("Joel", age: 30)
		b = batched.new("Joel", age: 30)

		assert_equal b.to_h, a.to_h
		assert_equal b.to_hash, a.to_hash
		assert_equal b.name, a.name
		assert_equal batched.instance_method(:initialize).parameters, unbatched.instance_method(:initialize).parameters

		b.age = 31
		assert_equal b.age, 31

		assert_raises(Literal::TypeError) { batched.new("Joel", age: "30") }
		assert_raises(ArgumentError) { batched.new("Joel") }
	end

	test "nested batches compile once, when the outermost commits" do
		inside = nil

		example = counted do
			props do
				prop :name, String

				props do
					prop :age, Integer
				end

				inside = schema_compilations
			end
		end

		assert_equal inside, 0
		assert_equal example.schema_compilations, 1
		assert_equal example.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
	end

	test "repeated batches each compile once" do
		example = counted do
			props do
				prop :name, String
				prop :age, Integer
			end

			props do
				prop :email, String
				prop :admin, _Boolean
			end
		end

		assert_equal example.schema_compilations, 2
		assert_equal example.new(name: "Joel", age: 30, email: "joel@example.com", admin: true).to_h.keys, [:name, :age, :email, :admin]
	end

	test "begin_props and commit_props are the two halves of props" do
		example = counted do
			begin_props
			prop :name, String
			prop :age, Integer
			commit_props
		end

		assert_equal example.schema_compilations, 1
		assert_equal example.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
	end

	test "commit_props without an open batch raises" do
		example = counted { prop :name, String }

		assert_raises(Literal::ArgumentError) { example.commit_props }
	end

	test "an exception inside props closes the batch and keeps the props declared before it" do
		example = counted

		assert_raises(RuntimeError) do
			example.props do
				example.prop :name, String
				raise "oops"
			end
		end

		assert_equal example.schema_compilations, 1

		example.prop :age, Integer
		assert_equal example.schema_compilations, 2
		assert_equal example.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
	end

	test "a prop added outside a batch after a batch recompiles" do
		example = counted do
			props do
				prop :name, String
			end
		end

		example.prop :age, Integer

		assert_equal example.schema_compilations, 2
		assert_equal example.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
	end

	test "an instance built while the batch is open sees every prop declared so far, and closes the shape" do
		early = nil
		refused = nil

		example = counted do
			props do
				prop :name, String
				prop :age, Integer
				early = new(name: "Joel", age: 30)
				begin
					prop :email, _Nilable(String)
				rescue Literal::ArgumentError => error
					refused = error
				end
			end
		end

		assert_equal early.to_h, { name: "Joel", age: 30 }
		assert refused.message.include?("because it already has instances")
		assert_equal example.literal_properties.map(&:name), [:name, :age]
	end

	test "a user-defined initializer that calls super works while the batch is open" do
		calls = 0
		early = nil

		counted do
			define_method(:initialize) do |**kwargs|
				calls += 1
				super(**kwargs)
			end

			props do
				prop :name, String, reader: :public
				early = new(name: "Joel")
			end
		end

		assert_equal calls, 1
		assert_equal early.name, "Joel"
	end

	test "a check declared inside a batch is enforced" do
		example = counted do
			props do
				prop :min, Integer
				prop :max, Integer
				check(:max, "must be greater than %{min}") { |max:, min:| max > min }
			end
		end

		assert_equal example.schema_compilations, 1
		assert_equal example.new(min: 1, max: 2).to_h, { min: 1, max: 2 }
		assert_raises(Literal::CheckError) { example.new(min: 2, max: 1) }
	end

	test "freezing a class with an open batch compiles what is pending" do
		example = counted do
			begin_props
			prop :name, String
			freeze
		end

		assert_equal example.schema_compilations, 1
		assert_equal example.new(name: "Joel").to_h, { name: "Joel" }
	end

	test "freezing inside props leaves nothing to commit" do
		example = counted do
			props do
				prop :name, String
				freeze
			end
		end

		assert_equal example.schema_compilations, 1
		assert_equal example.new(name: "Joel").to_h, { name: "Joel" }
	end

	test "a property named hash never displaces the generated hash" do
		declarations = proc do
			prop :name, String
			prop :hash, String, reader: false
		end

		unbatched = Class.new(Literal::Struct, &declarations)
		batched = Class.new(Literal::Struct) { props { class_exec(&declarations) } }

		[unbatched, batched].each do |example|
			a = example.new(name: "Joel", hash: "abc")
			b = example.new(name: "Joel", hash: "abc")

			assert_equal({ a => 1 }[b], 1)
		end
	end

	test "a subclass batches independently of its parent" do
		parent = counted do
			props do
				prop :name, String
				prop :age, Integer
			end
		end

		child = Class.new(parent) do
			props do
				prop :email, String
				prop :admin, _Boolean
			end
		end

		assert_equal parent.schema_compilations, 1
		assert_equal child.schema_compilations, 1
		assert_equal parent.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
		assert_equal child.new(name: "Joel", age: 30, email: "joel@example.com", admin: true).to_h.keys, [:name, :age, :email, :admin]
	end

	test "a subclass without props, built while its parent's batch is open, sees the parent's props" do
		child = nil
		instance = nil

		counted do
			props do
				prop :name, String
				child = Class.new(self)
				instance = child.new(name: "Joel")
			end
		end

		assert_equal instance.to_h, { name: "Joel" }
	end

	test "Literal::Struct compiles hash and == once per batch" do
		example = counted(Literal::Struct) do
			props do
				prop :name, String
				prop :age, Integer
			end
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

	test "Literal::Struct instances compare by every prop while the batch is open" do
		equal_early = nil
		hashes_early = nil

		counted(Literal::Struct) do
			props do
				prop :name, String
				a = from_props(name: "Joel")
				b = from_props(name: "Jill")
				equal_early = a == b
				hashes_early = a.hash == b.hash
			end
		end

		assert_equal equal_early, false
		assert_equal hashes_early, false
	end

	test "Literal::Data works batched" do
		example = counted(Literal::Data) do
			props do
				prop :name, String
				prop :age, Integer
			end
		end

		a = example.new(name: "Joel", age: 30)

		assert_equal example.schema_compilations, 1
		assert a.frozen?
		assert_equal a, example.new(name: "Joel", age: 30)
		assert_equal a.hash, example.new(name: "Joel", age: 30).hash
		assert_equal example.from_props(name: "Joel", age: 30), a
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
			props do
				prop :name, String
				prop :age, Integer
				prop :email, String
			end
		end

		projection = origin.slice(:name, :age)

		assert_equal projection.schema_compilations, 1
		assert_equal projection.new(name: "Joel", age: 30).to_h, { name: "Joel", age: 30 }
	end

	class BatchedColor < Literal::Enum(Integer)
		extend CountsSchemaCompilations

		props do
			prop :hex, String
			prop :warm, _Boolean, predicate: :public
		end

		Red = new(1, hex: "#f00", warm: true)
		Blue = new(2, hex: "#00f", warm: false)
	end

	test "Literal::Enum works with a batch" do
		assert_equal BatchedColor.schema_compilations, 1
		assert_equal BatchedColor::Red.hex, "#f00"
		assert_equal BatchedColor::Red.to_h, { value: 1, hex: "#f00", warm: true }
		assert BatchedColor::Red.warm?
	end

	test "Literal::Enum members can be built while the batch is open" do
		example = Class.new(Literal::Enum(String)) do
			begin_props
			prop :label, String
			prop :rank, _Nilable(Integer)
			const_set(:A, new("a", label: "A"))
			const_set(:B, new("b", label: "B", rank: 2))
			commit_props
		end

		assert_equal example["a"].to_h, { value: "a", label: "A", rank: nil }
		assert_equal example["b"].to_h, { value: "b", label: "B", rank: 2 }
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

	test "threads calling a schema-wide method while a batch is open generate it once" do
		entered = Queue.new
		release = Queue.new

		example = counted do
			begin_props
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

	test "a property named after a schema-wide method does not displace it while the batch is open" do
		early = nil

		example = Class.new(Literal::Struct) do
			prop :name, String

			begin_props
			prop :hash, _Nilable(String), reader: false
			early = { from_props(name: "Joel") => 1 }[from_props(name: "Joel")]
			commit_props
		end

		assert_equal early, 1
		assert_equal example.new(name: "Joel", hash: "abc").hash, example.new(name: "Joel", hash: "abc").hash
	end

	test "generating can define another shape with a batch of its own" do
		inner = nil

		outer = Class.new(Literal::Struct) do
			props do
				# Asking the union whether it takes nil materializes the deferred member.
				prop :child, _Union(String, _Deferred {
					inner ||= Class.new(Literal::Struct) do
						props do
							prop :name, String
						end
					end

					_Nilable(inner)
				})
			end
		end

		assert_equal outer.new.to_h, { child: nil }
		assert_equal outer.new(child: inner.new(name: "Joel")).child.name, "Joel"
	end

	test "a reader named after a schema-wide method is refused, batch or not" do
		declarations = proc { prop :to_h, String, reader: :public }

		assert_raises(Literal::ArgumentError) { Class.new { extend Literal::Properties }.class_exec(&declarations) }
		assert_raises(Literal::ArgumentError) { Class.new { extend Literal::Properties }.tap { |it| it.props { it.class_exec(&declarations) } } }

		example = Class.new { extend Literal::Properties }.tap { |it| it.props { it.prop :to_h, String } }
		assert_equal example.new(to_h: "x").to_h, { to_h: "x" }
	end

	test "a Literal::Enum frozen by hand is not mistaken for a finished one" do
		example = Class.new(Literal::Enum(String)) do
			freeze
		end

		assert_raises(ArgumentError) { example.__send__(:defined) }
	end
end
