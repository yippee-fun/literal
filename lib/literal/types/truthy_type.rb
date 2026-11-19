# frozen_string_literal: true

# @api private
class Literal::Types::TruthyType
	Instance = new.freeze
	include Literal::Type

	def inspect
		"_Truthy"
	end

	def ===(value)
		!!value
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::TruthyType, true
			true
		else
			false
		end
	end

	freeze
end
