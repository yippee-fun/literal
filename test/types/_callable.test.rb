# frozen_string_literal: true

class CallableTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Callable === -> {}
		assert _Callable === method(:puts)

		refute _Callable === nil
	end

	test "hierarchy" do
		assert_subtype _Callable, _Callable

		assert_subtype Proc, _Callable
		assert_subtype Method, _Callable

		assert_subtype _String(_Callable), _Callable
		assert_subtype _Interface(:call, :to_s), _Callable

		refute_subtype String, _Callable
		refute_subtype Object, _Callable

		assert_subtype _Intersection(Object, _Callable), _Callable
		refute_subtype _Intersection(Object, String), _Callable
	end
end
