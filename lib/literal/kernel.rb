# frozen_string_literal: true

require "literal"

# Opt-in global sugar, loaded with `require "literal/kernel"`: a bare
# `undefined` anywhere in the application returns `Literal::Undefined`.
#
# Literal never loads this itself — a typo'd bare `undefined` would otherwise
# stop raising NameError and start flowing a truthy sentinel through the
# program, and that trade-off belongs to the application, not the library.
module Kernel
	private def undefined
		Literal::Undefined
	end
end
