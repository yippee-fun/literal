# frozen_string_literal: true

include Literal::Types

test "result block returns a checked result" do
	result = Literal::Result(Integer, Symbol) do |type|
		type.success(42)
	end

	assert Literal::Success === result
	assert_equal 42, result.value!
end

test "result block wraps returned success values" do
	result = Literal::Result(Integer, Symbol) do
		42
	end

	assert result.success?
	assert_equal 42, result.value!
	assert_equal Integer, result.success_type
	assert_equal Symbol, result.failure_type
end

test "result block checks returned values against success type" do
	error = assert_raises(Literal::TypeError) do
		Literal::Result(Integer, Symbol) do
			"42"
		end
	end

	assert_equal Integer, error.to_h[:expected]
	assert_equal "42", error.to_h[:actual]
end

test "result block must return a matching result" do
	assert_raises(Literal::TypeError) do
		Literal::Result(Integer, Symbol) do
			Literal::Result(String, Symbol) { |type| type.success("42") }
		end
	end
end

test "then adopts returned success type" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }
		.then { |value| Literal::Result(String, RuntimeError) { |type| type.success(value.to_s) } }

	assert result.success?
	assert_equal "42", result.value!
	assert Literal::Result(String, _Union(Symbol, RuntimeError)) === result
end

test "then unions failure types" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }
		.then { Literal::Result(String, RuntimeError) { |type| type.failure(RuntimeError.new("boom")) } }

	assert result.failure?
	assert RuntimeError === result.error!
	assert Literal::Result(String, _Union(Symbol, RuntimeError)) === result
end

test "failure then does not yield" do
	original = Literal::Result(Integer, Symbol) { |type| type.failure(:nope) }
	yielded = false

	result = original.then do
		yielded = true
		Literal::Result(String, RuntimeError) { |type| type.success("ok") }
	end

	refute yielded
	assert result.equal?(original)
end

test "then block must return result" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }

	error = assert_raises(Literal::ArgumentError) do
		result.then(&:to_s)
	end

	assert_equal "Expected block to return a Literal::Result, got String", error.message
end

test "failure map updates success type metadata" do
	result = Literal::Result(Integer, Symbol) { |type| type.failure(:nope) }
	mapped = result.map(String, &:to_s)

	assert mapped.failure?
	assert_equal :nope, mapped.error!
	assert_equal String, mapped.success_type
	assert_equal Symbol, mapped.failure_type
end

test "success deconstruct_keys delegates to wrapped value" do
	person_class = Class.new do
		def initialize(name)
			@name = name
		end

		def deconstruct_keys(keys)
			h = { name: @name }
			keys ? h.slice(*keys) : h
		end
	end

	result = Literal::Result(person_class, Symbol) { |type| type.success(person_class.new("Joel")) }

	assert_equal({ name: "Joel" }, result.deconstruct_keys([:name]))
	assert_equal({}, result.deconstruct_keys([:value]))
end

test "failure deconstruct_keys delegates to wrapped error" do
	error_class = Class.new do
		def initialize(message)
			@message = message
		end

		def deconstruct_keys(keys)
			h = { message: @message }
			keys ? h.slice(*keys) : h
		end
	end

	result = Literal::Result(String, error_class) { |type| type.failure(error_class.new("oops")) }

	assert_equal({ message: "oops" }, result.deconstruct_keys([:message]))
	assert_equal({}, result.deconstruct_keys([:error]))
end

test "deconstruct_keys returns empty hash when wrapped object does not support it" do
	success = Literal::Result(Integer, Symbol) { |type| type.success(1) }
	failure = Literal::Result(String, Symbol) { |type| type.failure(:oops) }

	assert_equal({}, success.deconstruct_keys([:anything]))
	assert_equal({}, failure.deconstruct_keys([:anything]))
end

test "pattern matches success with positional pattern" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(1) }

	matched = case result
	in Literal::Success[Integer]
		true
	else
		false
	end

	assert matched
end

test "pattern matches success with delegated keyword pattern" do
	message_class = Class.new do
		def initialize(message)
			@message = message
		end

		def deconstruct_keys(keys)
			h = { message: @message }
			keys ? h.slice(*keys) : h
		end
	end

	result = Literal::Result(message_class, Symbol) { |type| type.success(message_class.new("Hello")) }

	matched = case result
	in Literal::Success[message: "Hello"]
		true
	else
		false
	end

	assert matched
end
