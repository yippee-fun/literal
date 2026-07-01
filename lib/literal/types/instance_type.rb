# frozen_string_literal: true

# @api private
class Literal::Types::InstanceType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Instance(#{@type.name})"
	end

	def ===(value)
		value.instance_of?(@type)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::InstanceType
			other.type == @type
		else
			false
		end
	end

	def <=(other, context: nil)
		case other
		when Module
			Literal.subtype?(@type, other, context:)
		else
			false
		end
	end

	freeze
end
