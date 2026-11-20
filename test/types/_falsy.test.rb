# frozen_string_literal: true

class FalsyTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		falsy_objects = Set[false, nil]
		truthy_objects = Fixtures::Objects - falsy_objects

		falsy_objects.each do |object|
			assert _Falsy === object
		end

		truthy_objects.each do |object|
			refute _Falsy === object
		end
	end

	test "hierarchy" do
		assert_subtype _Falsy, _Falsy
		assert_subtype false, _Falsy
		assert_subtype nil, _Falsy

		refute_subtype true, _Falsy
		refute_subtype 0, _Falsy
		refute_subtype "string", _Falsy
	end
end
