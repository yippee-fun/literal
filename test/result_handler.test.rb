# frozen_string_literal: true

include Literal::Types

test "handles success cases" do
	result = Literal::Result(String, Symbol) { |type| type.success("hello") }

	handled = result.handle do |on|
		on.success(String, &:upcase)
		on.failure(Symbol)
	end

	assert_equal "HELLO", handled
end

test "handles failure cases" do
	result = Literal::Result(String, Symbol) { |type| type.failure(:missing) }

	handled = result.handle do |on|
		on.success(String)
		on.failure(Symbol) { |error| "error: #{error}" }
	end

	assert_equal "error: missing", handled
end

test "raises for unhandled result" do
	result = Literal::Result(String, Symbol) { |type| type.success("hello") }

	error = assert_raises(Literal::ArgumentError) do
		result.handle do |on|
			on.failure(Symbol) { |it| it }
		end
	end

	assert_equal "No success handler covers String", error.message
end

test "can ignore a branch without a block" do
	result = Literal::Result(String, Symbol) { |type| type.success("hello") }

	handled = result.handle do |on|
		on.success(String)
		on.failure(Symbol)
	end

	assert_equal nil, handled
end

test "treats split handlers as exhaustive for union success types" do
	result = Literal::Result(_Union(String, Integer), Symbol) { |type| type.success("hello") }

	handled = result.handle do |on|
		on.success(String, &:upcase)
		on.success(Integer) { |value| value + 1 }
		on.failure(Symbol)
	end

	assert_equal "HELLO", handled
end

test "treats split handlers as exhaustive for union failure types" do
	result = Literal::Result(String, _Union(Symbol, RuntimeError)) { |type| type.failure(RuntimeError.new("boom")) }

	handled = result.handle do |on|
		on.success(String)
		on.failure(Symbol) { |error| "symbol: #{error}" }
		on.failure(RuntimeError, &:message)
	end

	assert_equal "boom", handled
end

test "uses mapped success type metadata for failure coverage" do
	result = Literal::Result(Integer, Symbol) { |type| type.failure(:missing) }
		.map(String, &:to_s)

	handled = result.handle do |on|
		on.success(String)
		on.failure(Symbol) { |error| "error: #{error}" }
	end

	assert_equal "error: missing", handled
end
