# frozen_string_literal: true

class SymbolTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Symbol(_Interface(:to_sym)) === :symbol
		assert _Symbol(size: 6) === :symbol

		refute _Symbol(_Interface(:non_existing_method)) === :symbol
		refute _Symbol(size: 5) === :symbol
	end
end
