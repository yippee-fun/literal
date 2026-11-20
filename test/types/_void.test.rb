# frozen_string_literal: true

class VoidTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		Fixtures::Objects.each do |object|
			assert _Void === object
		end
	end

	test "hierarchy" do
		assert_subtype _Void, _Void
		assert_subtype _Void, _Any?
		assert_subtype _Any?, _Void
		assert_subtype nil, _Void
		assert_subtype Object, _Void
	end
end
