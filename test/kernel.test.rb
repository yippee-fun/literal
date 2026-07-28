# frozen_string_literal: true

# These assertions run in subprocesses: requiring "literal/kernel" in the test
# process would define Kernel#undefined for the whole suite, masking any
# accidental internal dependency on the opt-in global.

LIB = File.expand_path("../lib", __dir__)

test "requiring literal does not define a global undefined" do
	assert system(
		RbConfig.ruby, "-I", LIB, "-r", "literal",
		"-e", "exit !Object.private_method_defined?(:undefined)"
	) do
		"Expected requiring literal alone not to define Kernel#undefined."
	end
end

test "requiring literal/kernel defines a global undefined" do
	assert system(
		RbConfig.ruby, "-I", LIB, "-r", "literal/kernel",
		"-e", "exit undefined.equal?(Literal::Undefined)"
	) do
		"Expected requiring literal/kernel to make a bare `undefined` return Literal::Undefined."
	end
end

test "requiring literal does not define globals never or void" do
	%w[never void].each do |name|
		assert system(
			RbConfig.ruby, "-I", LIB, "-r", "literal",
			"-e", "exit !Object.private_method_defined?(:#{name})"
		) do
			"Expected requiring literal alone not to define Kernel##{name}."
		end
	end
end

test "requiring literal/kernel defines globals never and void" do
	assert system(
		RbConfig.ruby, "-I", LIB, "-r", "literal/kernel",
		"-e", "exit never.equal?(Literal::Types::NeverType::Instance)"
	) do
		"Expected requiring literal/kernel to make a bare `never` return the NeverType instance."
	end

	assert system(
		RbConfig.ruby, "-I", LIB, "-r", "literal/kernel",
		"-e", "exit void.equal?(Literal::Types::VoidType::Instance)"
	) do
		"Expected requiring literal/kernel to make a bare `void` return the VoidType instance."
	end
end
