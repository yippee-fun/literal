# frozen_string_literal: true

class Literal::Types::DeferredType
	include Literal::Type
	include Literal::Types::DraftTransparent

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

	# Wrapped rather than materialized: the deferred constant may not be
	# defined yet when the relaxed type is built.
	def __relax__(&relax)
		Literal::Types::DeferredType.new { relax.call(materialize) }
	end

	# Types are immutable and built bottom-up, so a type graph can only cycle
	# through a deferred type. Guarding here alone stops a cyclic value from
	# recursing forever: re-entry with the same value answers false.
	def ===(other)
		Literal.with_match_guard(self, other) { materialize === other }
	end

	def >=(other, context: nil)
		Literal.subtype?(other, materialize, context:)
	end

	freeze
end
