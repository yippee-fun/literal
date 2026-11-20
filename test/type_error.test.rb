# frozen_string_literal: true

class TypeErrorTest < Quickdraw::Test
	Age = Literal::Value(Integer, 18..)

	test do
		Age.new(17)
	rescue => error
		assert_equal error.class, Literal::TypeError
		assert_equal error.message, "Type mismatch\n\n" \
			"    _Constraint(Integer, 18..)\n" \
			"      Expected: 18..\n" \
			"      Actual (Integer): 17\n"

		# deconstruct_keys
		key_names = [:receiver, :method, :label, :actual]
		exp_keys = {
					receiver: nil,
					method: nil,
					label: nil,
					actual: 17,
			}
		assert_equal error.deconstruct_keys(key_names), exp_keys
	end

	test "a nil expected type is still reported" do
		error = assert_raises(Literal::TypeError) { Literal.check(1, nil) }

		assert error.message.include?("Expected: nil\n")
		assert error.message.include?("Actual (Integer): 1\n")
	end

	test "interpolates as its message" do
		error = assert_raises(Literal::TypeError) { Literal.check(1, String) }

		assert_equal error.to_s, error.message
		assert error.full_message.include?("Expected: String")
	end

	test "deconstructs every key when asked for all of them" do
		error = assert_raises(Literal::TypeError) { Literal.check(1, String) }

		matched = case error
		in { expected:, actual: 1, **rest }
			[expected, rest.key?(:children)]
		end

		assert_equal matched, [String, true]
	end

	test "has a message before it's raised" do
		error = Literal::TypeError.new(
			context: Literal::TypeError::Context.new(receiver: Object.new, method: "#foo", expected: Integer, actual: "x")
		)

		assert_equal error.message, "Type mismatch\n\nObject#foo\n  Expected: Integer\n  Actual (String): \"x\"\n"
	end

	test "renders a BasicObject" do
		error = assert_raises(Literal::TypeError) { Literal.check(BasicObject.new, String) }

		assert_equal error.to_s, error.message
		assert(/Actual \(BasicObject\): #<BasicObject:0x\h+>\n/.match?(error.message))
	end

	test "renders a BasicObject's own inspect" do
		object = Class.new(BasicObject) { def inspect = "custom" }.new
		error = assert_raises(Literal::TypeError) { Literal.check(object, String) }

		assert error.message.include?("): custom\n")
	end

	test "a value whose inspect raises is rendered" do
		object = Class.new { def inspect = raise("boom") }.new
		error = assert_raises(Literal::TypeError) { Literal.check(object, String) }

		assert(/Actual \(#<Class:0x\h+>\): #<#<Class:0x\h+> \(inspect raised RuntimeError\)>\n/.match?(error.message))
	end

	test "a value with a __send__ property is rendered" do
		shape = Class.new(Literal::Data) { prop :__send__, String }
		error = assert_raises(Literal::TypeError) { Literal.check(shape.new(__send__: "x"), String) }

		assert error.message.include?("Expected: String\n")
	end
end
