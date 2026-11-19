# frozen_string_literal: true

# @api private
class Literal::Types::VoidType
	Instance = new.freeze

	include Literal::Type

	def inspect
		"_Void"
	end

	def ===(_)
		true
	end

	def literal_supertype_of?(_, context:)
		true
	end

	freeze
end
