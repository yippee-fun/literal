# frozen_string_literal: true

class ProcableTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Procable === proc {}
		assert _Procable === -> {}
		assert _Procable === method(:puts)

		refute _Procable === "string"
		refute _Procable === 42
		refute _Procable === nil
	end

	test "hierarchy" do
		assert_subtype _Procable, _Procable
		assert_subtype _Lambda, _Procable

		assert_subtype Method, _Procable
		assert_subtype Proc, _Procable
		assert_subtype Symbol, _Procable

		refute_subtype String, _Procable
	end
end
