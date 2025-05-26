# frozen_string_literal: true

# @api private
class Literal::Types::NilableType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def inspect
		"_Nilable(#{@type.inspect})"
	end

	def ===(value)
		nil === value || @type === value
	end

	def record_literal_type_errors(ctx)
		@type.record_literal_type_errors(ctx) if @type.respond_to?(:record_literal_type_errors)
	end

	def >=(other)
		case other
		when Literal::Types::NilableType
			Literal.subtype?(other.type, @type)
		when nil
			true
		else
			Literal.subtype?(other, @type)
		end
	end

	freeze
end
