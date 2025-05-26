# frozen_string_literal: true

class Literal::Tuple
	class Generic
		include Literal::Type

		def initialize(*types)
			@types = types
		end

		attr_reader :types

		def ===(other)
			return false unless Literal::Tuple === other
			types = @types
			other_types = other.__types__

			return false unless types.size == other_types.size

			i, len = 0, types.size
			while i < len
				return false unless Literal.subtype?(other_types[i], types[i])
				i += 1
			end

			true
		end

		def >=(other)
			case other
			when Literal::Tuple::Generic
				types = @types
				other_types = other.types

				return false unless types.size == other_types.size

				i, len = 0, types.size
				while i < len
					return false unless Literal.subtype?(other_types[i], types[i])
					i += 1
				end

				true
			else
				false
			end
		end

		def new(*values)
			Literal::Tuple.new(values, @types)
		end
	end

	def initialize(values, types)
		@__values__ = values
		@__types__ = types
	end

	def inspect
		"Literal::Tuple(#{@__types__.map(&:inspect).join(', ')})#{@__values__.inspect}"
	end

	attr_reader :__values__, :__types__

	def ==(other)
		(Literal::Tuple === other) && (@__values__ == other.__values__)
	end

	def [](index)
		@__values__[index]
	end
end
