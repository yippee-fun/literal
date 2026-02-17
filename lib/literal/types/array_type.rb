# frozen_string_literal: true

# @api private
class Literal::Types::ArrayType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Array(#{@type.inspect})"
	end

	def ===(value)
		Array === value && value.all?(@type)
	end

	def >=(other)
		case other
		when Literal::Types::ArrayType
			Literal.subtype?(other.type, @type)
		else
			false
		end
	end

	def record_literal_type_errors(context)
		unless Array === context.actual
			return
		end

		context.actual.each_with_index do |item, index|
			unless @type === item
				context.add_child(label: "[#{index}]", expected: @type, actual: item)
			end
		end
	end

	freeze
end
