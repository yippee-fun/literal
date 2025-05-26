# frozen_string_literal: true

class Literal::Flags32 < Literal::Flags
	BYTES = 4
	BITS = BYTES * 8
	PACKER = "L"
end
