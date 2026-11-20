# frozen_string_literal: true

# @api private
class Literal::Types::ClassType
	include Literal::Type

	def initialize(type)
		@type = type
		@hash = [Literal::Types::ClassType, type].hash
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::ClassType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::ClassType === other && @type.eql?(other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Class(#{@type.name})"
	end

	def literal_upper_bound
		Class
	end

	def ===(value)
		Class === value && (value == @type || !!(value < @type))
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::ClassType
			Literal.subtype?(other.type, @type, context:)
		when Literal::Types::DescendantType
			(Class === other.type) && Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
