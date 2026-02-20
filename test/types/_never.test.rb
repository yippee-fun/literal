# frozen_string_literal: true

include Literal::Types

test "===" do
	Fixtures::Objects.each do |object|
		refute _Never === object
	end

	refute _Never === nil
end

test "subtyping" do
	assert_subtype _Never, Integer
	assert_subtype _Never, _Union(Integer, String)
	assert_subtype _Never, _Intersection(_Any?)
	assert_subtype _Never, _Never
end
