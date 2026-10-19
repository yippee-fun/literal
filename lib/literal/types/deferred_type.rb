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
		# Frozen before its first use, say by Ractor.make_shareable ahead of the
		# constants the block names, so it can no longer remember the answer.
		return __materialize_frozen__ if frozen?

		__materialize__
	end

	# The same guard as __materialize__, kept outside the frozen object.
	private def __materialize_frozen__
		materializing = (Thread.current[:__literal_materializing__] ||= {}.compare_by_identity)
		return self if materializing.key?(self)

		begin
			materializing[self] = true
			@block.call
		ensure
			materializing.delete(self)
		end
	end

	private def __materialize__
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

	def ===(other)
		materialize === other
	end

	def >=(other, context: nil)
		Literal.subtype?(other, materialize, context:)
	end
end
