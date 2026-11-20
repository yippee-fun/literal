# frozen_string_literal: true

class PropertiesReaderTest < Quickdraw::Test
	Example = Literal::Object

	test "no reader by default" do
		example = Class.new(Example) do
			prop :example, String
		end

		object = example.new(
			example: "hello",
		)

		refute object.public_methods.include?(:example)
		refute object.protected_methods.include?(:example)
		refute object.private_methods.include?(:example)
	end

	test "false reader" do
		example = Class.new(Example) do
			prop :example, String, reader: false
		end

		object = example.new(
			example: "hello",
		)

		refute object.public_methods.include?(:example)
		refute object.protected_methods.include?(:example)
		refute object.private_methods.include?(:example)
	end

	test "private reader" do
		example = Class.new(Example) do
			prop :example, String, reader: :private
		end

		object = example.new(
			example: "hello",
		)

		assert object.private_methods.include?(:example)
		assert_equal(object.__send__(:example), "hello")
	end

	test "protected reader" do
		example = Class.new(Example) do
			prop :example, String, reader: :protected
		end

		object = example.new(
			example: "hello",
		)

		assert object.protected_methods.include?(:example)
		assert_equal(object.__send__(:example), "hello")
	end

	test "public reader" do
		example = Class.new(Example) do
			prop :example, String, reader: :public
		end

		object = example.new(
			example: "hello",
		)

		assert object.public_methods.include?(:example)
		assert_equal(object.example, "hello")
	end
end
