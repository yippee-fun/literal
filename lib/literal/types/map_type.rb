# frozen_string_literal: true

# @api private
class Literal::Types::MapType
	include Literal::Type

	def initialize(shape)
		@shape = shape
		freeze
	end

	attr_reader :shape

	def inspect
		"_Map(#{@shape.inspect})"
	end

	def ===(other)
		Hash === other && @shape.each do |k, v|
			return false unless v === other[k]
		end
	end

	def record_literal_type_errors(context)
		unless Hash === context.actual
			return
		end

		@shape.each do |key, expected|
			unless context.actual.key?(key) || expected === nil
				context.add_child(label: "[#{key.inspect}]", expected:, actual: nil)
				next
			end

			actual = context.actual[key]
			unless expected === actual
				context.add_child(label: "[#{key.inspect}]", expected:, actual:)
			end
		end
	end

	def >=(other)
		case other
		when Literal::Types::MapType
			other_shape = other.shape

			@shape.all? do |k, v|
				Literal.subtype?(other_shape[k], v)
			end
		else
			false
		end
	end
end
