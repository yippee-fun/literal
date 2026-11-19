# frozen_string_literal: true

class Literal::Types::DeferredType
	include Literal::Type
	include Literal::Types::DraftTransparent

	UNMATERIALIZED = Object.new.freeze
	# Shared rather than per instance, so a materialized deferred type can still
	# be made Ractor-shareable. It is held only to publish a result.
	PUBLISHING = Mutex.new

	def initialize(&block)
		@block = block
		@materialized = UNMATERIALIZED
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

	# A thread re-entering its own materialization — a deferred type that refers
	# to itself — gets the deferred type back. Other threads run the block
	# themselves rather than wait, since the block can wait on locks they hold
	# (like shape generation), and the first result published is everyone's.
	def materialize
		return @materialized unless UNMATERIALIZED.equal?(@materialized)

		materializing = (Thread.current[:literal_materializing] ||= [])
		return self if materializing.any? { |deferred| deferred.equal?(self) }

		materializing.push(self)

		begin
			result = @block.call
		ensure
			materializing.pop
		end

		PUBLISHING.synchronize do
			@materialized = result if UNMATERIALIZED.equal?(@materialized)
			@materialized
		end
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
		Literal.with_match_guard(self, other) { !!(materialize === other) }
	end

	def >=(other, context: nil)
		Literal.subtype?(other, materialize, context:)
	end

	freeze
end
