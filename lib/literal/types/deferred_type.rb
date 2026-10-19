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

	# Only a call that materializes writes to the type, so once materialized it can be frozen
	# (or made shareable with Ractor.make_shareable). A type frozen before its first use
	# cannot cache, and evaluates its block every time.
	def materialize
		return @materialized unless UNMATERIALIZED.equal?(@materialized)
		return @block.call if frozen?
		return self if @materializing

		begin
			@materializing = true
			@materialized = @block.call
		ensure
			@materializing = false
		end
	end

	# Wrapped rather than materialized: the deferred constant may not be
	# defined yet when the relaxed type is built.
	def __relax__(&relax)
		Literal::Types::DeferredType.new { relax.call(materialize) }
	end

	# A check made while the block is still running - say, one it sets off by autoloading a
	# constant - gets the type straight from the block, since materialize can only return self
	def ===(other)
		type = materialize
		type.equal?(self) ? @block.call === other : type === other
	end

	def >=(other, context: nil)
		Literal.subtype?(other, materialize, context:)
	end
end
