# frozen_string_literal: true

class SignedGreeter
	extend Literal::Signatures

	sig(String, greeting: _Nilable(String)) >> String
	def greet(name, greeting: "Hello") = "#{greeting || 'Hi'}, #{name}"

	sig(Integer) >> String
	def broken(count) = count

	sig(_Integer(1..)) >> _Array(String)
	def repeat(times, &) = Array.new(times, &)

	sig(String) >> String
	def self.shout(text) = text.upcase

	sig(String) >> String
	private def whisper(text) = text.downcase

	def unsigned(anything) = anything
end

module SignedHelpers
	extend Literal::Signatures

	sig(Integer, Integer) >> Integer
	def add(a, b) = a + b
end

module SignedFunctions
	extend Literal::Signatures

	sig(String, times: Integer) >> String
	def shout(text, times: 1) = text.upcase * times
	module_function :shout

	module_function # rubocop:disable Style/AccessModifierDeclarations, Style/ModuleFunction

	sig(String) >> String
	def whisper(text) = text.downcase
end

test "checks both copies of a module function named after it is defined" do
	assert_equal SignedFunctions.shout("a", times: 2), "AA"
	assert_equal Object.new.extend(SignedFunctions).__send__(:shout, "a"), "A"

	error = assert_raises(Literal::TypeError) { SignedFunctions.shout(1) }
	assert error.message.include?("SignedFunctions.shout")
	assert_raises(Literal::TypeError) { SignedFunctions.shout("a", times: "2") }
	assert_raises(Literal::TypeError) { Object.new.extend(SignedFunctions).__send__(:shout, 1) }
end

test "checks both copies of a method defined under module_function" do
	assert_equal SignedFunctions.whisper("A"), "a"
	assert_equal Object.new.extend(SignedFunctions).__send__(:whisper, "A"), "a"

	error = assert_raises(Literal::TypeError) { SignedFunctions.whisper(1) }
	assert error.message.include?("SignedFunctions.whisper")
	assert_raises(Literal::TypeError) { Object.new.extend(SignedFunctions).__send__(:whisper, 1) }
end

test "exports a method redefined without a sig unchecked" do
	mod = Module.new do
		extend Literal::Signatures
		body = -> (text) { text }

		sig(String) >> String
		define_method(:echo, body)
		define_method(:echo, body)
		module_function :echo
	end

	assert_equal mod.echo(1), 1
end

test "keeps a module's signed methods apart from its clone's" do
	mod = Module.new do
		extend Literal::Signatures

		sig(String) >> String
		def echo(text) = text
	end

	mod.clone.module_eval do
		sig(Integer) >> Integer
		def echo(number) = number
	end

	mod.__send__(:module_function, :echo)
	assert_equal mod.echo("a"), "a"
	assert_raises(Literal::TypeError) { mod.echo(1) }
end

test "leaves a singleton method of the same name with no sig alone" do
	mod = Module.new do
		extend Literal::Signatures

		sig(String) >> String
		def name_of(text) = text

		def self.name_of(anything) = anything
	end

	assert_equal mod.name_of(1), 1
end

test "checks a module function under a prepended singleton override" do
	mod = Module.new do
		extend Literal::Signatures
		singleton_class.prepend(Module.new { def twice(text) = super * 2 })

		sig(String) >> String
		def twice(text) = text
		module_function :twice
	end

	assert_equal mod.twice("a"), "aa"
	assert_raises(Literal::TypeError) { mod.twice(1) }
end

test "exports a prepended override as module_function does" do
	mod = Module.new do
		extend Literal::Signatures
		prepend(Module.new { def name_of(text) = "override" })

		sig(String) >> String
		def name_of(text) = text
		module_function :name_of
	end

	assert_equal mod.name_of("a"), "override"
end

test "checks a signed singleton method made private" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> String
		def self.build(text) = text
		private_class_method :build
	end

	assert_raises(NoMethodError) { klass.build("a") }
	assert_equal klass.__send__(:build, "a"), "a"
	assert_raises(Literal::TypeError) { klass.__send__(:build, 1) }
end

test "checks each argument before the method runs" do
	error = assert_raises(Literal::TypeError) { SignedGreeter.new.greet(1) }

	assert error.message.include?("SignedGreeter#greet")
	assert error.message.include?("name")
end

test "checks a keyword argument by name" do
	error = assert_raises(Literal::TypeError) { SignedGreeter.new.greet("Joel", greeting: 1) }

	assert error.message.include?("greeting:")
end

test "leaves an omitted argument to its default, which it does not check" do
	assert_equal SignedGreeter.new.greet("Joel"), "Hello, Joel"
	assert_equal SignedGreeter.new.greet("Joel", greeting: nil), "Hi, Joel"
end

test "checks the return value" do
	error = assert_raises(Literal::TypeError) { SignedGreeter.new.broken(1) }

	assert error.message.include?("return")
end

test "passes a block through" do
	assert_equal SignedGreeter.new.repeat(2, &:to_s), ["0", "1"]
	assert_raises(Literal::TypeError) { SignedGreeter.new.repeat(2) { |i| i } }
end

test "types a singleton method, naming its owner" do
	assert_equal SignedGreeter.shout("hi"), "HI"

	error = assert_raises(Literal::TypeError) { SignedGreeter.shout(1) }
	assert error.message.include?("SignedGreeter.shout")
end

test "keeps the method's visibility" do
	assert_raises(NoMethodError) { SignedGreeter.new.whisper("HI") }
	assert_equal SignedGreeter.new.__send__(:whisper, "HI"), "hi"
	assert_raises(Literal::TypeError) { SignedGreeter.new.__send__(:whisper, 1) }
end

test "leaves a method with no sig alone" do
	assert_equal SignedGreeter.new.unsigned(1), 1
end

test "types the methods of a module" do
	calculator = Class.new { include SignedHelpers }.new

	assert_equal calculator.add(1, 2), 3
	assert_raises(Literal::TypeError) { calculator.add(1, "2") }
end

test "checks an override that calls a signed super" do
	parent = Class.new do
		extend Literal::Signatures

		sig(Integer) >> Integer
		def double(number) = number * 2
	end

	child = Class.new(parent) do
		sig(Integer) >> Integer
		def double(number) = super + 1
	end

	assert_equal child.new.double(2), 5
	assert_raises(Literal::TypeError) { child.new.double("2") }
end

test "wraps the method under a prepended override" do
	decorator = Module.new do
		def double(number) = super + 1
	end

	klass = Class.new do
		extend Literal::Signatures
		prepend decorator

		sig(Integer) >> Integer
		def double(number) = number * 2
	end

	assert_equal klass.new.double(2), 5
	assert_raises(Literal::TypeError) { klass.new.double("2") }
end

test "lets a method under a prepended override call super" do
	parent = Class.new do
		def double(number) = number * 10
	end

	decorator = Module.new do
		def double(number) = super + 1
	end

	klass = Class.new(parent) do
		extend Literal::Signatures
		prepend decorator

		sig(Integer) >> Integer
		def double(number) = super * 2
	end

	assert_equal klass.new.double(2), 41
	assert_raises(Literal::TypeError) { klass.new.double("2") }
end

test "keeps refusing keywords a method refuses" do
	klass = Class.new do
		extend Literal::Signatures

		sig(Hash) >> Hash
		def echo(options, **nil) = options
	end

	assert_equal klass.new.echo({ flag: true }), { flag: true }
	assert_raises(::ArgumentError) { klass.new.echo(flag: true) }
end

test "lets Ruby refuse a missing argument" do
	assert_raises(::ArgumentError) { SignedGreeter.new.greet }
end

test "names the method in a backtrace" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> _Void
		def fail(message) = raise(message)
	end

	error = assert_raises(RuntimeError) { klass.new.fail("boom") }
	assert_equal error.backtrace_locations.first.label.split("#").last, "fail"
end

test "keeps a method captured before re-signing on the body it was signed with" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> String
		def echo(text) = "old #{text}"
	end

	captured = klass.new.method(:echo)

	klass.class_eval do
		sig(String) >> String
		def echo(text) = "new #{text}"
	end

	assert_equal captured.call("a"), "old a"
	assert_equal klass.new.echo("a"), "new a"
end

test "refuses to load a sig with no return type" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(String)
			def greet(name) = name
		end
	end

	assert error.message.include?("has no return type")
end

test "binds past a class's own method hooks that do not call super" do
	klass = Class.new do
		def self.method_added(name) = nil
		def self.singleton_method_added(name) = nil

		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name

		sig(String) >> String
		def self.shout(text) = text
	end

	assert_raises(Literal::TypeError) { klass.new.greet(1) }
	assert_raises(Literal::TypeError) { klass.shout(1) }
end

test "binds past a subclass's own method hooks that do not call super" do
	parent = Class.new do
		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name
	end

	child = Class.new(parent) do
		def self.method_added(name) = nil
		def self.singleton_method_added(name) = nil

		sig(String) >> String
		def hello(name) = name

		sig(String) >> String
		def self.shout(text) = text
	end

	assert_raises(Literal::TypeError) { child.new.hello(1) }
	assert_raises(Literal::TypeError) { child.shout(1) }
end

test "signs a subclass's method once under both classes' hooks" do
	seen = []

	parent = Class.new do
		define_singleton_method(:method_added) do |name|
			seen << [:parent, name]
			super(name)
		end

		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name
	end

	child = Class.new(parent) do
		define_singleton_method(:method_added) do |name|
			seen << [:child, name]
			super(name)
		end

		sig(String) >> String
		def hello(name) = name
	end

	assert_equal seen, [[:parent, :greet], [:child, :hello], [:parent, :hello]]
	assert_equal child.private_instance_methods(false).grep(/unsigned/).size, 1
	assert_raises(Literal::TypeError) { child.new.hello(1) }
end

test "signs past method hooks a class prepends after signing, without calling super" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name

		singleton_class.prepend(Module.new do
			private def method_added(name) = nil
			private def singleton_method_added(name) = nil
		end)

		sig(String) >> String
		def hello(name) = name

		sig(String) >> String
		def self.shout(text) = text
	end

	assert_equal klass.private_instance_methods(false).grep(/unsigned/).size, 2
	assert_raises(Literal::TypeError) { klass.new.hello(1) }
	assert_raises(Literal::TypeError) { klass.shout(1) }
end

test "handles each method once under a module's older hooks" do
	seen = []

	mod = Module.new do
		extend Literal::Signatures

		sig(String) >> String
		def echo(text) = text

		singleton_class.prepend(Module.new do
			define_method(:method_added) do |name|
				seen << name
				super(name)
			end
		end)

		sig(String) >> String
		def shout(text) = text.upcase
		module_function :echo, :shout
	end

	assert_equal seen, [:shout]
	assert_equal mod.private_instance_methods(false).grep(/unsigned/).size, 2
	assert_equal mod.shout("a"), "A"
	assert_raises(Literal::TypeError) { mod.echo(1) }
	assert_raises(Literal::TypeError) { mod.shout(1) }
end

test "signs past a class's own reflection methods" do
	reflection = [
		:instance_method,
		:define_method,
		:alias_method,
		:private_method_defined?,
		:protected_method_defined?,
		:private,
		:protected,
		:public,
		:singleton_class,
		:ancestors,
		:prepend,
	]

	klass = Class.new do
		extend Literal::Signatures

		singleton_class.class_eval do
			reflection.each { |name| define_method(name) { |*| raise "called #{name}" } }
		end

		sig(String) >> String
		def greet(name) = name

		sig(String) >> String
		def self.shout(text) = text
	end

	assert_equal klass.new.greet("Joel"), "Joel"
	assert_raises(Literal::TypeError) { klass.new.greet(1) }
	assert_raises(Literal::TypeError) { klass.shout(1) }
end

test "labels a class past its own name, to_s and inspect" do
	labelled = Class.new do
		def self.name = raise("called name")
		def self.to_s = raise("called to_s")
		def self.inspect = raise("called inspect")

		extend Literal::Signatures
	end

	klass = Class.new(labelled) do
		sig(String) >> String
		def greet(name) = name

		sig(String) >> String
		def self.shout(text) = text
	end

	assert_raises(Literal::TypeError) { klass.new.greet(1) }
	error = assert_raises(Literal::TypeError) { klass.shout(1) }
	assert error.message.include?("#<Class:0x")

	mismatch = assert_raises(Literal::ArgumentError) do
		Class.new(labelled) do
			sig(String, String) >> String
			def greet(name) = name
		end
	end
	assert mismatch.message.start_with?("#<Class:0x")

	dangling = assert_raises(Literal::ArgumentError) do
		Class.new(labelled) do
			sig(String) >> String
			sig(String) >> String
		end
	end
	assert dangling.message.start_with?("#<Class:0x")
end

test "lets a class's own method hooks see each method once it is signed" do
	klass = Class.new do
		def self.seen = (@seen ||= [])

		def self.method_added(name)
			seen << [name, File.basename(instance_method(name).source_location.first)]
			super
		end

		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name
	end

	assert_equal klass.seen, [[:greet, "signatures.rb"]]
end

test "keeps a visibility a class's own hook sets" do
	klass = Class.new do
		def self.method_added(name)
			private(name)
			super
		end

		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name
	end

	assert klass.private_method_defined?(:greet)
end

test "keeps the sig from a method a class's own hook defines" do
	klass = Class.new do
		def self.method_added(name)
			alias_method(:"#{name}_unwrapped", name) unless name.end_with?("_unwrapped")
			super
		end

		extend Literal::Signatures

		sig(String) >> String
		def greet(name) = name
	end

	assert_raises(Literal::TypeError) { klass.new.greet(1) }
end

test "binds through a module that includes Literal::Signatures" do
	dsl = Module.new { include Literal::Signatures }

	klass = Class.new do
		extend dsl

		sig(String) >> String
		def greet(name) = name
	end

	assert_raises(Literal::TypeError) { klass.new.greet(1) }
end

test "takes Literal::Undefined as a return type" do
	klass = Class.new do
		extend Literal::Signatures

		sig >> Literal::Undefined
		def nothing = Literal::Undefined
	end

	assert_equal klass.new.nothing, Literal::Undefined
end

test "refuses to load a sig whose positional types do not match" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(String, String) >> String
			def greet(name) = name
		end
	end

	assert error.message.include?("takes 1 positional argument, its sig types 2")
end

test "refuses to load a sig whose keywords do not match" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(id: String) >> String
			def find(user_id:) = user_id
		end
	end

	assert error.message.include?("takes keywords [:user_id], its sig types [:id]")
end

test "refuses to load a sig on a method that takes a splat" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(String) >> String
			def greet(*names) = names.join
		end
	end

	assert error.message.include?("takes names as a splat")
end

test "does not watch for an end a block will never reach" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> String
	end

	assert_equal klass.instance_variable_get(:@__literal_signature_watch__), nil
	assert_raises(Literal::ArgumentError) { klass.sig(String) }
end

test "refuses a sig with no method after it before the next" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(String) >> String
			sig(String) >> String
		end
	end

	assert error.message.include?("has no method after it")
end

# TruffleRuby has no TracePoint, so there the next sig catches a dangling one.
unless RUBY_ENGINE == "truffleruby"
	test "forgets a dangling sig once it is refused" do
		namespace = Module.new

		assert_raises(Literal::ArgumentError) do
			namespace.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Reopened
					extend Literal::Signatures

					sig(String) >> String
				end
			RUBY
		end

		namespace.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
			class Reopened
				def pair(a, b) = [a, b]
			end
		RUBY

		assert_equal namespace::Reopened.new.pair(1, 2), [1, 2]
	end

	test "lets an error raised after a sig end the class body" do
		assert_raises(NameError) do
			Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Typo
					extend Literal::Signatures

					sig(String) >> Strng
					def greet(name) = name
				end
			RUBY
		end
	end

	test "refuses a dangling sig after an error rescued in the class body" do
		error = assert_raises(Literal::ArgumentError) do
			Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Rescued
					extend Literal::Signatures

					sig(String) >> String
					begin
						raise "rescued"
					rescue RuntimeError
					end
				end
			RUBY
		end

		assert error.message.include?("has no method after it")
	end

	test "refuses to load a class body that ends on a sig" do
		error = assert_raises(Literal::ArgumentError) do
			Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Dangling
					extend Literal::Signatures

					sig(String) >> String
				end
			RUBY
		end

		assert error.message.include?("Dangling: the sig at")
		assert error.message.include?("has no method after it")
	end

	test "labels a class body that ends on a sig past its own to_s" do
		error = assert_raises(Literal::ArgumentError) do
			Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Dangling
					def self.to_s = raise("called to_s")

					extend Literal::Signatures

					sig(String) >> String
				end
			RUBY
		end

		assert error.message.include?("Dangling: the sig at")
	end

	test "lets go of the watch once it is done" do
		namespace = Module.new
		namespace.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
			class Bound
				extend Literal::Signatures

				sig(String) >> String
				def greet(name) = name
			end

			class Refused
				extend Literal::Signatures

				begin
					sig(String) >> String
					sig(String) >> String
				rescue Literal::ArgumentError
				end
			end
		RUBY

		assert_raises(Literal::ArgumentError) do
			namespace.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
				class Dangling
					extend Literal::Signatures

					sig(String) >> String
				end
			RUBY
		end

		[namespace::Bound, namespace::Refused, namespace::Dangling].each do |klass|
			assert_equal klass.instance_variable_get(:@__literal_signature_watch__), nil
		end
	end
end

test "stops watching for an end once it refuses a second sig" do
	Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
		class Twice
			extend Literal::Signatures

			begin
				sig(String) >> String
				sig(String) >> String
			rescue Literal::ArgumentError
			end
		end
	RUBY
end

test "does not watch for an end once the method is defined" do
	Module.new.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
		class Settled
			extend Literal::Signatures

			sig(String) >> String
			def greet(name) = name

			class Nested; end
		end
	RUBY
end

class SignedShapes
	extend Literal::Signatures

	sig(Integer, _Nilable(Integer)) >> Integer
	def sum(a, b = 10) = a + (b || 0)

	sig(if: _Boolean) >> _Boolean
	def flip(if:) = !binding.local_variable_get(:if)

	sig(Integer) >> Integer
	def [](index) = index * 2

	sig >> _Boolean
	def empty? = true
end

test "checks an optional positional argument only when it is passed" do
	shapes = SignedShapes.new

	assert_equal shapes.sum(1), 11
	assert_equal shapes.sum(1, nil), 1
	error = assert_raises(Literal::TypeError) { shapes.sum(1, "2") }
	assert error.message.include?("b")
end

test "types a keyword named after a reserved word" do
	assert_equal SignedShapes.new.flip(if: true), false
	assert_raises(Literal::TypeError) { SignedShapes.new.flip(if: 1) }
end

test "reads a reserved-word keyword past a method named binding" do
	klass = Class.new do
		extend Literal::Signatures

		def binding = raise("shadowed")

		sig(if: _Boolean) >> _Boolean
		def flip(if:) = !::Kernel.binding.local_variable_get(:if)
	end

	assert_equal klass.new.flip(if: true), false
end

test "types operator and predicate methods" do
	assert_equal SignedShapes.new[2], 4
	assert_raises(Literal::TypeError) { SignedShapes.new["2"] }
	assert_equal SignedShapes.new.empty?, true
end

test "types a method whose name def cannot spell, without evaluating it" do
	klass = Class.new do
		extend Literal::Signatures

		sig(String) >> String
		define_method(:"kebab-case") { |text| text }

		sig(String) >> String
		define_method(:"run(text); end; raise 'injected'; def other") { |text| text }
	end

	assert_equal klass.new.public_send(:"kebab-case", "a"), "a"
	assert_raises(Literal::TypeError) { klass.new.public_send(:"kebab-case", 1) }
	assert_equal klass.new.public_send(:"run(text); end; raise 'injected'; def other", "a"), "a"
end

test "lets Ruby refuse too many arguments or an unknown keyword before checking" do
	klass = Class.new do
		extend Literal::Signatures

		sig(_Nilable(Integer)) >> _Nilable(Integer)
		def first(value = nil) = value

		sig(greeting: _Nilable(String)) >> _Nilable(String)
		def greet(greeting: nil) = greeting
	end

	assert_raises(::ArgumentError) { klass.new.first("1", 2) }
	assert_raises(::ArgumentError) { klass.new.greet(greeting: 1, other: 1) }
end

test "passes on only the optional keywords given" do
	klass = Class.new do
		extend Literal::Signatures

		sig(Integer, _Nilable(Integer), if: String, a: Integer, b: Integer) >> Array
		def collect(x, y = 2, if:, a: 3, b: 4) = [x, y, binding.local_variable_get(:if), a, b]
	end

	assert_equal klass.new.collect(1, if: "i"), [1, 2, "i", 3, 4]
	assert_equal klass.new.collect(1, 5, if: "i", b: 6), [1, 5, "i", 3, 6]
	assert_equal klass.new.collect(1, nil, if: "i", a: 7, b: 8), [1, nil, "i", 7, 8]
	assert_raises(Literal::TypeError) { klass.new.collect(1, if: "i", b: "6") }
end

test "keeps the method's parameters" do
	klass = Class.new do
		extend Literal::Signatures

		sig(Integer, _Nilable(Integer), key: String, option: Integer) >> Integer
		def blocked(value, extra = nil, key:, option: 1, &callback) = value

		sig(Integer, _Nilable(Integer), key: String, option: Integer) >> Integer
		def plain(value, extra = nil, key:, option: 1) = value

		sig(Integer, Integer) >> Array
		def ignored(_, _) = []
	end

	assert_equal klass.instance_method(:blocked).parameters, [[:req, :value], [:opt, :extra], [:keyreq, :key], [:key, :option], [:block, :callback]]
	assert_equal klass.instance_method(:plain).parameters.first(4), [[:req, :value], [:opt, :extra], [:keyreq, :key], [:key, :option]]
	assert_equal klass.instance_method(:plain).arity, -3
	assert_raises(Literal::TypeError) { klass.new.ignored(1, "2") }
end

test "keeps a repeated underscore name's arguments apart" do
	klass = Class.new do
		extend Literal::Signatures

		sig(Integer, _x: String) >> Symbol
		def keyword(_x, _x:) = :keyword

		sig(Integer) >> Symbol
		def block(_x, &_x) = :block
	end

	assert_equal klass.new.keyword(1, _x: "a"), :keyword
	assert_raises(Literal::TypeError) { klass.new.keyword(1, _x: 2) }
	assert_equal klass.new.block(1) { nil }, :block
end

test "keeps its own locals apart from the method's parameters" do
	klass = Class.new do
		extend Literal::Signatures

		sig(Integer, __literal_arg_0__: String) >> Integer
		def first(value, __literal_arg_0__:) = value

		sig(_Nilable(Integer), __literal_optional__: String) >> _Nilable(Integer)
		def second(value = nil, __literal_optional__:) = value
	end

	assert_equal klass.new.first(1, __literal_arg_0__: "a"), 1
	assert_equal klass.new.second(1, __literal_optional__: "a"), 1
end

test "refuses to load a sig on a method with a required argument after an optional one" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new do
			extend Literal::Signatures

			sig(Integer, Integer) >> Integer
			def pad(width = 1, value) = value + width
		end
	end

	assert error.message.include?("a required argument after an optional one")
end
