# frozen_string_literal: true

include Literal::Types

test "===" do
	predicate = _Predicate("starts with 'H'") { |it| it.start_with? "H" }

	assert predicate === "Hello"
	refute predicate === "World"
end

test "predicates are subtypes of themselves" do
	predicate = _Predicate("even", &:even?)

	assert_subtype predicate, predicate
end

test "predicate recursion rejects by default" do
	predicate = nil
	predicate = _Predicate("recursive") { |_it| predicate === :value }

	refute predicate === :value
end

test "predicate recursion can accept" do
	predicate = nil
	predicate = _Predicate("recursive", recursion: :accept) { |_it| predicate === :value }

	assert predicate === :value
end

test "=== returns a boolean" do
	predicate = _Predicate("has a name") { |it| it[:name] }

	assert_equal true, predicate === { name: "Joel" }
	assert_equal false, predicate === {}
end

test "inspect" do
	assert_equal %(_Predicate("say \\"hi\\"")), _Predicate(%(say "hi")) { true }.inspect
end
