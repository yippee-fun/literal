# frozen_string_literal: true

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
