# frozen_string_literal: true

# @api private
class Literal::Types::InstanceType
	include Literal::Type

	def initialize(type)
		@type = type
		@hash = [Literal::Types::InstanceType, type].hash
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::InstanceType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::InstanceType === other && @type.eql?(other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Instance(#{@type.name})"
	end

	def ===(value)
		value.instance_of?(@type)
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::InstanceType
			other.type == @type
		else
			false
		end
	end

	def literal_subtype_of?(other, context:)
		case other
		when Module
			Literal.subtype?(@type, other, context:)
		else
			false
		end
	end

	freeze
end
