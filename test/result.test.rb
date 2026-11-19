# frozen_string_literal: true

include Literal::Types

test "result block returns a checked result" do
	result = Literal::Result(Integer, Symbol) do |type|
		type.success(42)
	end

	assert Literal::Success === result
	assert_equal 42, result.value!
end

test "result block requires throwing a result" do
	error = assert_raises(Literal::ArgumentError) do
		Literal::Result(Integer, Symbol) do
			42
		end
	end

	assert_equal "Expected block to throw a success or failure result", error.message
end

test "result block must throw, not return, a result" do
	error = assert_raises(Literal::ArgumentError) do
		Literal::Result(Integer, Symbol) do
			Literal::Result(String, Symbol) { |type| type.success("42") }
		end
	end

	assert_equal "Expected block to throw a success or failure result", error.message
end

test "and_then adopts returned success type" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }
		.and_then { |value| Literal::Result(String, RuntimeError) { |type| type.success(value.to_s) } }

	assert result.success?
	assert_equal "42", result.value!
	assert Literal::Result(String, _Union(Symbol, RuntimeError)) === result
end

test "and_then unions failure types" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }
		.and_then { Literal::Result(String, RuntimeError) { |type| type.failure(RuntimeError.new("boom")) } }

	assert result.failure?
	assert RuntimeError === result.error!
	assert Literal::Result(String, _Union(Symbol, RuntimeError)) === result
end

test "failure and_then does not yield" do
	original = Literal::Result(Integer, Symbol) { |type| type.failure(:nope) }
	yielded = false

	result = original.and_then do
		yielded = true
		Literal::Result(String, RuntimeError) { |type| type.success("ok") }
	end

	refute yielded
	assert result.equal?(original)
end

test "also yields success value and returns self" do
	original = Literal::Result(Integer, Symbol) { |type| type.success(42) }
	yielded = nil

	result = original.also do |value|
		yielded = value
	end

	assert_equal 42, yielded
	assert result.equal?(original)
end

test "failure also does not yield" do
	original = Literal::Result(Integer, Symbol) { |type| type.failure(:nope) }
	yielded = false

	result = original.also do
		yielded = true
	end

	refute yielded
	assert result.equal?(original)
end

test "and_then block must return result" do
	result = Literal::Result(Integer, Symbol) { |type| type.success(42) }

	error = assert_raises(Literal::ArgumentError) do
		result.and_then(&:to_s)
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

test "result types with the same parameters are equal" do
	assert_equal Literal::Result(Integer, String), Literal::Result(Integer, String)
	assert Literal::Result(Integer, String).eql?(Literal::Result(Integer, String))
	assert_equal Literal::Result(Integer, String).hash, Literal::Result(Integer, String).hash
	refute_equal Literal::Result(Integer, String), Literal::Result(Integer, Symbol)

	assert_equal Literal::Success(Integer), Literal::Success(Integer)
	assert_equal Literal::Success(Integer).hash, Literal::Success(Integer).hash
	refute_equal Literal::Success(Integer), Literal::Failure(Integer)
	assert_equal Literal::Failure(String), Literal::Failure(String)
	assert_equal Literal::Failure(String).hash, Literal::Failure(String).hash
end

test "result types are covariant" do
	assert_subtype Literal::Result(Integer, String), Literal::Result(Integer, String)
	assert_subtype Literal::Result(Integer, String), Literal::Result(Numeric, _Union(String, Symbol))
	refute_subtype Literal::Result(Numeric, String), Literal::Result(Integer, String)
	refute_subtype Literal::Result(Integer, Symbol), Literal::Result(Integer, String)

	assert_subtype Literal::Success(Integer), Literal::Success(Numeric)
	refute_subtype Literal::Success(Numeric), Literal::Success(Integer)
	assert_subtype Literal::Failure(Integer), Literal::Failure(Numeric)
	refute_subtype Literal::Failure(Integer), Literal::Success(Integer)
end

test "success and failure types are subtypes of results that admit them" do
	assert_subtype Literal::Success(Integer), Literal::Result(Numeric, String)
	assert_subtype Literal::Failure(String), Literal::Result(Integer, String)
	refute_subtype Literal::Success(String), Literal::Result(Integer, String)
	refute_subtype Literal::Result(Integer, String), Literal::Success(Integer)
end

test "result types are subtypes of their classes" do
	assert_subtype Literal::Result(Integer, String), Literal::Result
	assert_subtype Literal::Success(Integer), Literal::Success
	assert_subtype Literal::Success(Integer), Literal::Result
	assert_subtype Literal::Failure(Integer), Literal::Failure
	refute_subtype Literal::Result(Integer, String), Literal::Success
end

test "a property can be redefined with an equal result type" do
	parent = Class.new do
		extend Literal::Properties

		prop :result, Literal::Result(Integer, String)
	end

	refute_raises do
		Class.new(parent) do
			prop :result, Literal::Result(Integer, String)
		end
	end
end

test "result types inspect as their constructors" do
	assert_equal Literal::Result(Integer, String).inspect, "Literal::Result(Integer, String)"
end

test "result types match only results" do
	assert_equal (Literal::Result(Integer, String) === 1), false
	assert_equal (Literal::Result(Integer, String) === nil), false
end

test "results with equal contents are equal" do
	type = Literal::Result(Integer, String)

	assert_equal type.success(1), type.success(1)
	assert type.success(1).eql?(type.success(1))
	assert_equal type.success(1).hash, type.success(1).hash
	assert_equal type.failure("no"), type.failure("no")
	assert_equal type.failure("no").hash, type.failure("no").hash

	refute_equal type.success(1), type.success(2)
	refute_equal type.failure("no"), type.failure("nope")
	refute_equal Literal::Result(String, String).success("no"), type.failure("no")
	refute type.success(1).eql?(Literal::Result(Float, String).success(1.0))
	assert_equal type.success(1), Literal::Result(Numeric, String).success(1)
end

test "a result is equal to itself, like an array, even holding NaN" do
	nan = Float::NAN
	success = Literal::Result(Float, Float).success(nan)
	failure = Literal::Result(Float, Float).failure(nan)

	assert_equal success, success
	assert success.eql?(success)
	assert_equal success, Literal::Result(Float, Float).success(nan)
	assert_equal failure, Literal::Result(Float, Float).failure(nan)
	assert failure.eql?(Literal::Result(Float, Float).failure(nan))

	refute_equal success, Literal::Result(Float, Float).success(0.0 / 0.0)
end

test "results holding a BasicObject compare and hash by identity" do
	object = BasicObject.new
	type = Literal::Result(BasicObject, BasicObject)

	assert_equal type.success(object), type.success(object)
	assert type.success(object).eql?(type.success(object))
	assert_equal type.success(object).hash, type.success(object).hash
	refute type.success(object).eql?(type.success(BasicObject.new))

	assert_equal type.failure(object), type.failure(object)
	assert type.failure(object).eql?(type.failure(object))
	assert_equal type.failure(object).hash, type.failure(object).hash
	refute type.failure(object).eql?(type.failure(BasicObject.new))
end

test "results use a BasicObject payload's singleton eql? and hash" do
	payloads = Array.new(2) do
		payload = BasicObject.new
		def payload.eql?(_other) = true
		def payload.hash = 1
		payload
	end
	type = Literal::Result(BasicObject, BasicObject)

	assert type.success(payloads[0]).eql?(type.success(payloads[1]))
	assert_equal type.success(payloads[0]).hash, type.success(payloads[1]).hash
end

test "results hash their payload with its own hash, even a private one" do
	payload = Class.new do
		def initialize(id) = @id = id
		attr_reader :id

		def eql?(other) = id == other.id
		private def hash = id.hash
	end

	type = Literal::Result(Object, Object)

	assert_equal type.success(payload.new(1)).hash, type.success(payload.new(1)).hash
	assert_equal type.failure(payload.new(1)).hash, type.failure(payload.new(1)).hash
	assert({ type.success(payload.new(1)) => true }[type.success(payload.new(1))])
end

test "results delegate equality and hashing through a delegator" do
	type = Literal::Result(BasicObject, BasicObject)

	assert type.success(SimpleDelegator.new(1)).eql?(type.success(SimpleDelegator.new(1)))
	assert_equal type.success(SimpleDelegator.new(1)).hash, type.success(SimpleDelegator.new(1)).hash
end

test "a result type is the union of its success and failure types" do
	result = Literal::Result(Integer, String)
	union = _Union(Literal::Success(Integer), Literal::Failure(String))

	assert_subtype result, union
	assert_subtype union, result
	assert_subtype result, _Union(Literal::Success(Numeric), Literal::Failure(_Union(String, Symbol)))
	assert_subtype result, _Union(Literal::Failure(String), Literal::Success(Integer), nil)
	assert_subtype result, Literal::Result
	assert_subtype result, _Nilable(Literal::Result(Numeric, String))

	refute_subtype result, Literal::Success(Integer)
	refute_subtype result, _Union(Literal::Success(Integer), Literal::Failure(Symbol))
	refute_subtype result, Literal::Success

	assert Literal::Result(String, Integer) <= Literal::Result(Object, Numeric)
	refute Literal::Result(String, Integer) <= Literal::Result(Object, String)
end
