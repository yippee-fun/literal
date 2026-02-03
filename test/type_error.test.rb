# frozen_string_literal: true

Age = Literal::Value(Integer, 18..)

test "has message" do
	Age.new(17)
rescue => error
	assert_equal error.class, Literal::TypeError
	assert_equal error.message, "Type mismatch\n\n" \
		"    _Constraint(Integer, 18..)\n" \
		"      Expected: 18..\n" \
		"      Actual (Integer): 17\n"
end

test "deconstruct_keys extracts specific keys" do
	Age.new(17)
rescue Literal::TypeError => error
	result = error.deconstruct_keys([:actual, :expected])

	assert_equal result[:actual], 17
	assert_equal result[:expected].class, Literal::Types::ConstraintType
end

test "deconstruct_keys with nil returns all keys" do
	Age.new(17)
rescue Literal::TypeError => error
	result = error.deconstruct_keys(nil)

	assert ([:receiver, :method, :label, :expected, :actual, :children] - result.keys).empty?
end

test "can be pattern matched" do
	Age.new(17)
rescue Literal::TypeError => error
	case error
		in expected: expected_type, actual: (..17) => actual_value, children: [{ label: child_label, expected: child_expected, actual: child_actual }]
			assert_equal expected_type.class, Literal::Types::ConstraintType
			assert_equal actual_value, 17
			assert_equal child_label, "_Constraint(Integer, 18..)"
			assert_equal child_expected, (18..)
			assert_equal child_actual, 17
	end
end
