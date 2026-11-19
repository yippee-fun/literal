# frozen_string_literal: true

include Literal::Types

test "===" do
	assert _Class(Enumerable) === Array

	refute _Class(Enumerable) === []
	refute _Class(Enumerable) === String
	refute _Class(Enumerable) === Enumerable
end

test "heirarchy" do
	assert_subtype _Class(Array), _Class(Enumerable)
	assert_subtype _Class(Enumerable), _Class(Enumerable)
	assert_subtype _Descendant(Array), _Class(Enumerable)
	assert_subtype _Descendant(Array), _Class(Array)

	refute_subtype _Descendant(Enumerable), _Class(Enumerable)
	refute_subtype Enumerable, _Class(Enumerable)
	refute_subtype Class, _Class(Enumerable)
end

test "=== returns a boolean" do
	assert_equal false, _Class(Integer) === String
end
