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

	def literal_child_types
		return enum_for(__method__) unless block_given?

		type = materialize
		yield type unless type.equal?(self)
	end

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
