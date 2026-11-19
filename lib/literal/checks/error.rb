# frozen_string_literal: true

class Literal::Checks::Error < Literal::Data
	prop :prop, _Nilable(Symbol)
	prop :message, String
	# Integer is admitted now so that indexed paths into collections can come
	# later without changing this public schema.
	prop :path, _Array(_Union(Symbol, Integer)), default: -> { [] }
end
