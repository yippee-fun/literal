# frozen_string_literal: true

class Literal::Flags64 < Literal::Flags
	BYTES = 8
	BITS = BYTES * 8
	PACKER = "Q"
end
