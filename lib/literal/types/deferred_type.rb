# frozen_string_literal: true

class Literal::Types::DeferredType
	include Literal::Type

	def initialize(&block)
		@block = block
	end

	attr_reader :block

	def inspect
		"_Deferred"
	end

	def ===(other)
		@block.call === other
	end

	def >=(other)
		Literal.subtype?(other, @block.call)
	end
end
