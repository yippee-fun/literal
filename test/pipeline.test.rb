# frozen_string_literal: true

extend Literal::Types

Foo = Literal::Pipeline(Integer => String) do
	step(String) do |i|
		success(i.to_s)
	end

	step(String) do |i|
		success(i.upcase)
	end
end

Bar = Literal::Function(String => Literal::Result(Integer, "a")) do |value|
	success(value.length)
end

Example = Literal::Pipeline(Integer) do
	step(Result(Integer, "a")) do |i|
		success(i * 2)
	end

	step(Integer) do |i|
		success(i + 1)
	end

	map(Integer) { |it| it * 2 }

	add_step(Foo)
	add_step(Bar)
end

test "it works" do
	assert_equal 2, Example.call(2) { |on|
		on.success { |value| value }
		on.failure("a")
	}
end
