# frozen_string_literal: true

class TruthyTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		truthy_objects = Fixtures::Objects - Set[false, nil]
		falsy_objects = Set[false, nil]

		truthy_objects.each do |object|
			assert _Truthy === object
		end

		falsy_objects.each do |object|
			refute _Truthy === object
		end
	end

	test "hierarchy" do
		assert_subtype true, _Truthy
		assert_subtype _Truthy, _Truthy
		assert_subtype _Not(_Not(true)), _Truthy
		assert_subtype _Not(_Not(_Truthy)), _Truthy

		refute_subtype false, _Truthy
		refute_subtype _Not(true), _Truthy
		refute_subtype _Not(_Truthy), _Truthy
	end
end
