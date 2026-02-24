# frozen_string_literal: true

# @api private
class Literal::Types::SameObjectType
	include Literal::Type

	EQUAL_METHOD = BasicObject.instance_method(:equal?)

	def initialize(object)
		@object = object
		freeze
	end

	attr_reader :object

	def ===(value)
		EQUAL_METHOD.bind_call(@object, value)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::SameObjectType
			EQUAL_METHOD.bind_call(@object, other.object)
		else
			false
		end
	end

	freeze
end
