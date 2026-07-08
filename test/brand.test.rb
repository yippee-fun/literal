# frozen_string_literal: true

include Literal::Types

test "brands checked non-string objects by identity" do
	brand = Literal::Brand(Array)
	value = []

	assert_equal brand.new(value), value
	assert brand === value
	refute brand === []
end

test ".[] is equivalent to .new" do
	brand = Literal::Brand(Array)
	value = []

	assert_equal brand[value], value
	assert brand === value
end

test "raises when the object does not match the type" do
	brand = Literal::Brand(String)

	assert_raises(Literal::TypeError) { brand.new(:user_123) }
end

test "does not create brands for immediate value types" do
	[
		Integer,
		Float,
		Symbol,
		NilClass,
		TrueClass,
		FalseClass,
		nil,
		true,
		false,
		_Boolean,
		_Falsy,
		_Nilable(Integer),
		_Union(Integer, Symbol),
		_Constraint(Integer, 18..),
	].each do |type|
		assert_raises(Literal::ArgumentError) { Literal::Brand(type) }
	end
end

test "creates brands for mixed immediate and object types" do
	brand = Literal::Brand(_Union(String, Integer))
	value = +"user-123"
	branded_value = brand.new(value)

	assert_equal branded_value, value
	assert brand === branded_value
	refute brand === value
end

test "does not brand immediate values" do
	brand = Literal::Brand(_Any?)

	[1, 1.0, :user_123, nil, true, false].each do |value|
		assert_raises(Literal::ArgumentError) { brand.new(value) }
		refute brand === value
	end
end

test "duplicates strings before branding" do
	brand = Literal::Brand(String)
	value = +"user-123"

	branded_value = brand.new(value)

	assert_equal branded_value, value
	refute branded_value.equal?(value)
	assert brand === branded_value
	refute brand === value
	refute brand === "user-123"
end

test "duplicated frozen strings stay frozen" do
	brand = Literal::Brand(String)
	value = "user-123"

	assert brand.new(value).frozen?
end

test "checks the duplicated frozen string" do
	value = "user-123"
	brand = Literal::Brand(_SameObject(value))

	assert_raises(Literal::TypeError) { brand.new(value) }
end

test "does not duplicate non-string objects" do
	brand = Literal::Brand(Array)
	value = []

	branded_value = brand.new(value)

	assert branded_value.equal?(value)
end

test "does not brand equal but distinct objects" do
	brand = Literal::Brand(Array)
	value = []

	brand.new(value)

	assert brand === value
	refute brand === []
end
