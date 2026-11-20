# frozen_string_literal: true

# @api private
class Literal::Types::NeverType
	Instance = new.freeze

	include Literal::Type

	def inspect
		"_Never"
	end

	def ===(value)
		false
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::NeverType
			true
		else
			false
		end
	end

	def literal_subtype_of?(_other, context:)
		true
	end

	freeze
end
