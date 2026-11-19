# frozen_string_literal: true

# @api private
class Literal::Types::EnumerableType
	include Literal::Type

	def initialize(type)
		@type = type
		freeze
	end

	attr_reader :type

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Enumerable(#{@type.inspect})"
	end

	def literal_upper_bound
		Enumerable
	end

	# An enumerable that reports no finite size may never finish iterating, or
	# may be consumed by it, so it can't be checked.
	def ===(value)
		return false unless Enumerable === value

		if unknown_size?(value)
			raise Literal::ArgumentError.new("Can't check the elements of an enumerable of unknown or infinite size: #{value.inspect}")
		end

		value.all?(@type)
	end

	# A size that requires arguments isn't a count, so it says nothing.
	private def unknown_size?(value)
		value.respond_to?(:size) && !(Integer === value.size)
	rescue ArgumentError
		false
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::EnumerableType
			Literal.structural_subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
