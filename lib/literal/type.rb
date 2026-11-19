# frozen_string_literal: true

module Literal::Type
	def >=(other, context: nil)
		self == other
	end

	def <=(other, context: nil)
		case other
		when Literal::Type
			other.>=(self, context:)
		else
			bound = literal_upper_bound
			!bound.nil? && Literal.subtype?(bound, other, context:)
		end
	end

	# A type admitting every value this one does, which answers whether this
	# type is a subtype of a module. nil when there is no useful bound.
	def literal_upper_bound
		nil
	end

	def literal_child_types
		enum_for(__method__) unless block_given?
	end

	def name
		Literal.const_name(self)
	end
end
