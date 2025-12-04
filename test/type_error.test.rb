# frozen_string_literal: true

test "Literal::TypeError#to_h returns a hash representation" do
	context = Literal::TypeError::Context.new
	error = Literal::TypeError.new(context:)

	result = error.to_h
	assert_equal Hash, result.class
end
