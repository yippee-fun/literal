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

test "types operator and predicate methods" do
	assert_equal SignedShapes.new[2], 4
	assert_raises(Literal::TypeError) { SignedShapes.new["2"] }
	assert_equal SignedShapes.new.empty?, true
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
