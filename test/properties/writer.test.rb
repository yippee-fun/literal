# frozen_string_literal: true

Example = Literal::Object

test "no writer by default" do
	example = Class.new(Example) do
		prop :example, String
	end

	object = example.new(
		example: "hello",
	)

	refute object.public_methods.include?(:example=)
	refute object.protected_methods.include?(:example=)
	refute object.private_methods.include?(:example=)
end

test "false writer" do
	example = Class.new(Example) do
		prop :example, String, writer: false
	end

	object = example.new(
		example: "hello",
	)

	refute object.public_methods.include?(:example)
	refute object.protected_methods.include?(:example)
	refute object.private_methods.include?(:example)
end

test "private writer" do
	example = Class.new(Example) do
		prop :example, String, writer: :private, reader: :public
	end

	object = example.new(
		example: "hello",
	)

	assert object.public_methods.include?(:example)
	assert_equal object.__send__(:example), "hello"
end

test "protected writer" do
	example = Class.new(Example) do
		prop :example, String, writer: :protected, reader: :public
	end

	object = example.new(
		example: "hello",
	)

	assert object.protected_methods.include?(:example=)
	assert_equal object.__send__(:example=, "world"), "world"
end

test "writers apply coercion" do
	example = Class.new(Example) do
		prop :example, String, writer: :public, reader: :public do |value|
			value.to_s.strip
		end
	end

	object = example.new(example: " hello ")

	assert_equal object.example, "hello"

	object.example = " world "

	assert_equal object.example, "world"
end

test "public writer" do
	example = Class.new(Example) do
		prop :example, String, writer: :public, reader: :public
	end

	object = example.new(
		example: "hello",
	)

	assert object.public_methods.include?(:example=)
	assert_equal object.example = "world", "world"
end
