# frozen_string_literal: true

# @api private
class Literal::Types::SetType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Set(#{@type.inspect})"
	end

	def ===(value)
		return false unless Set === value

		value.each do |v|
			return false unless @type === v
		end

		true
	end

	def record_literal_type_errors(context)
		return unless Set === context.actual

		context.actual.each do |actual|
			unless @type === actual
				context.add_child(label: "[]", expected: @type, actual:)
			end
		end
	end

	def >=(other)
		case other
		when Literal::Types::SetType
			Literal.subtype?(other.type, @type)
		else
			false
		end
	end

	freeze
end
