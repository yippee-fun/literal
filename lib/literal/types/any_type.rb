# frozen_string_literal: true

# @api private
class Literal::Types::AnyType
	Instance = new.freeze

	include Literal::Type

	def inspect
		"_Any"
	end

	def ===(value)
		!(nil === value)
	end

	# A type is a subtype of _Any if it rejects nil. Asking it may run user
	# code, such as a predicate, that isn't defined for nil, in which case we
	# can't tell.
	def >=(other, context: nil)
		!(other === nil)
	rescue
		false
	end

	freeze
end
