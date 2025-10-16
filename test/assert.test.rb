$a = 1

test "assert with local variable" do
	refute_raises do
		a = 1
		b = "Hello"

		binding.assert(a: Integer, b: String)
		binding.assert("a" => Integer, "b" => String)
	end

	assert_raises TypeError do
		a = 1
		binding.assert(a: String)
	end
end

test "assert with global variable" do
	refute_raises do
		binding.assert("$a": Integer)
	end

	assert_raises TypeError do
		binding.assert("$a": String)
	end
end

test "assert with instance variable" do
	refute_raises do
		@a = 1
		binding.assert("@a": Integer)
	end

	assert_raises TypeError do
		@a = 1
		binding.assert("@a": String)
	end
end

test "assert with class variable" do
	refute_raises do
		@@a = 1
		binding.assert("@@a": Integer)
	end

	assert_raises TypeError do
		@@a = 1
		binding.assert("@@a": String)
	end
end
