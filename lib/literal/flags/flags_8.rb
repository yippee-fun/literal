# frozen_string_literal: true

class Literal::Flags8 < Literal::Flags
	BYTES = 1
	BITS = BYTES * 8
	PACKER = "C"
end
