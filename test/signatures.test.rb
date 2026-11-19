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
