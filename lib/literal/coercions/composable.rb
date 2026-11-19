# frozen_string_literal: true

# Coercion composition for objects that act as coercions via #to_proc, such
# as collection generics — `Literal::Array(String) >> Immutable`.
module Literal::Coercions::Composable
	def >>(other)
		Literal::Coercion(&to_proc) >> other
	end

	def <<(other)
		Literal::Coercion(&to_proc) << other
	end
end
