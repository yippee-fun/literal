# frozen_string_literal: true

class Literal::Flags16 < Literal::Flags
	BYTES = 2
	BITS = BYTES * 8
	PACKER = "S"
end
