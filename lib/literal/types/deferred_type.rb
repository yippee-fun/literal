# frozen_string_literal: true

class Literal::Types::DeferredType
	include Literal::Type

	UNMATERIALIZED = Object.new.freeze

	def initialize(&block)
		@block = block
		@materialized = UNMATERIALIZED
		@materializing = false
	end

	attr_reader :block

	def inspect
		"_Deferred"
	end

	def materialize
		return @materialized unless UNMATERIALIZED.equal?(@materialized)
		return self if @materializing

		@materializing = true
		@materialized = @block.call
	ensure
		@materializing = false
	end

	def ===(other)
		materialize === other
	end

	def >=(other, context: nil)
		Literal.subtype?(other, materialize, context:)
	end
end
