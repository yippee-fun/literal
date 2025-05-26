# frozen_string_literal: true

# @api private
class Literal::Types::HashType
	include Literal::Type

	def initialize(key_type, value_type)
		@key_type = key_type
		@value_type = value_type
		freeze
	end

	attr_reader :key_type, :value_type

	def inspect
		"_Hash(#{@key_type.inspect}, #{@value_type.inspect})"
	end

	def ===(value)
		return false unless Hash === value

		value.each do |k, v|
			return false unless @key_type === k && @value_type === v
		end

		true
	end

	def >=(other)
		case other
		when Literal::Types::HashType
			(
				Literal.subtype?(other.key_type, @key_type)
			) && (
				Literal.subtype?(other.value_type, @value_type)
			)
		else
			false
		end
	end

	def record_literal_type_errors(context)
		unless Hash === context.actual
			return
		end

		context.actual.each do |key, item|
			unless @key_type === key
				context.add_child(label: "[]", expected: @key_type, actual: key)
				next
			end

			unless @value_type === item
				context.add_child(label: "[#{key.inspect}]", expected: @value_type, actual: item)
			end
		end
	end

	freeze
end
