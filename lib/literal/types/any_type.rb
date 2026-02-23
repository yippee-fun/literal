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

	def >=(other, context: nil)
		!(other === nil)
	end

	freeze
end
