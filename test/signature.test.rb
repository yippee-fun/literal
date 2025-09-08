# frozen_string_literal: true

test "validates required positional arguments (single arg)" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(a)
			p a
		end
	end

	refute_raises { example.new.hi(1) }
	assert_raises(Literal::Signature::Error) { example.new.hi(:a) }
end

test "validates required positional arguments (multiple args)" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(a, b)
			p a
		end
	end

	refute_raises { example.new.hi(1, nil) }
	assert_raises(Literal::Signature::Error) { example.new.hi(:a, nil) }
end

test "validates optional positional arguments" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(a = :a)
			p a
		end
	end

	refute_raises { example.new.hi(1) }
	assert_raises(Literal::Signature::Error) { example.new.hi(:a) }
	# NOTE: the default value can't be checked as it can't be determined
	# in a "method decorator" before calling the original method for real.
	refute_raises { example.new.hi }
end

test "validates positional rest arguments" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(*a)
			p a
		end
	end

	refute_raises { example.new.hi }
	refute_raises { example.new.hi(1) }
	assert_raises(Literal::Signature::Error) { example.new.hi(:a) }
end

test "validates required keyword arguments" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(a:)
			p a
		end
	end

	refute_raises { example.new.hi(a: 1) }
	assert_raises(Literal::Signature::Error) { example.new.hi(a: :a) }
end

test "validates optional keyword arguments" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(a: :a)
			p a
		end
	end

	refute_raises { example.new.hi(a: 1) }
	assert_raises(Literal::Signature::Error) { example.new.hi(a: :a) }
	# NOTE: the default value can't be checked as it can't be determined
	# in a "method decorator" before calling the original method for real.
	refute_raises { example.new.hi }
end

test "validates keyword rest arguments" do
	example = Class.new do
		extend Literal::Signature

		sig a: _Integer
		def hi(**a)
			p a
		end
	end

	refute_raises { example.new.hi(a: 1, b: 2) }
	assert_raises(Literal::Signature::Error) { example.new.hi(a: 1, b: :a) }
end
