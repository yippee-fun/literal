# frozen_string_literal: true

EXAMPLES = {
	Integer => [
		0,
		1,
	],
	Hash => [
		{},
		{ a: 1 },
		{ a: 1, b: 2 },
	],
	Numeric => [
		1.0,
		-1.0,
	],
	Symbol => [
		:a,
		:"",
	],
	Range => [
		(1..10),
		("a".."z"),
	],
	Set => [
		Set[],
		Set[1, 2, 3],
	],
	Time => [
		Time.now,
	],
	Array => [
		[],
		[1, 2, 3],
	],
	String => [
		"a",
	],
	Float => [
		1.0,
		-1.0,
	],
	Regexp => [
		/a/,
		/a/i,
	],
}

Literal::Transforms.each do |type, transforms|
	transforms.each do |method, new_type|
		test "#{type}.#{method} transforms to #{new_type}" do
			examples = EXAMPLES.fetch(type)

			examples.each do |example|
				assert new_type === method.call(example) do
					"Expected #{example.inspect}.#{method.inspect} to return #{new_type.inspect}, but got #{method.call(example).inspect}"
				end
			end
		end
	end
end

test "Range#size can be nil or Infinity, so mapping it to Integer is checked" do
	# TruffleRuby makes a new Proc for each Symbol#to_proc, so finds no transform.
	if (transform = Literal::Transforms[Range][:size.to_proc])
		assert transform === (1..).size
	end

	assert_raises(Literal::TypeError) do
		Literal::Array(Range).new("a".."z", 1..).map(Integer, &:size)
	end
end
