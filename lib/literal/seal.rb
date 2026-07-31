# frozen_string_literal: true

# A composable property seal. Wraps a callable that fixes a value's final
# representation — freezing it, for example — running after any coercion and
# before the type check. Unlike coercions, seals run on every path that
# stores a value into a real object: the initializer, writers, `from_props`,
# and `marshal_load`. Drafts drop the seal — their state stays mutable — and
# it is re-applied when the draft finalizes.
#
# Seals must be idempotent and type-preserving.
#
# A seal may carry a coercion that runs before it, from compositions like
# `NilIfEmpty >> Immutable`. Nothing can compose after a seal, and a seal is
# deliberately not callable — so `Proc#>>` rejects `raw_proc >> seal` at
# composition time instead of silently demoting the seal to a coercion.
#
# Construct with `Literal::Seal(&block)`.
class Literal::Seal
	class << self
		def [](...)
			new(...)
		end
	end

	def initialize(callable = nil, coercion: nil, &block)
		callable ||= block

		unless callable
			raise Literal::ArgumentError.new("Literal::Seal requires a callable or a block.")
		end

		@callable = __proc_from__(callable)
		@coercion = coercion

		pipeline = self
		seal = @callable

		@proc = coercion ? proc { |value| seal.call(coercion.call(value)) } : proc { |value| seal.call(value) }
		@proc.define_singleton_method(:__literal_pipeline__) { pipeline }

		freeze
	end

	# The full pipeline (coercion, then seal) as a Proc, for property
	# definitions — `prop :tags, _Array(String), &Immutable` — and for
	# standalone use like `values.map(&Immutable)`. The returned proc carries
	# a reference back to this object, so `prop` can split the pipeline into
	# the property's coercion and seal slots.
	def to_proc
		@proc
	end

	def coercion_proc
		@coercion
	end

	def seal_proc
		@callable
	end

	def >>(other)
		other = other.__literal_pipeline__ if other.respond_to?(:__literal_pipeline__)

		case other
		when Literal::Seal
			if other.coercion_proc
				raise Literal::ArgumentError.new(
					"A coercion cannot run after a seal. Compose as `coercion >> seal` or `seal << coercion` instead.",
				)
			end

			Literal::Seal.new(__compose__(@callable, other.seal_proc), coercion: @coercion)
		else
			raise Literal::ArgumentError.new(
				"A coercion cannot run after a seal. Compose as `coercion >> seal` or `seal << coercion` instead.",
			)
		end
	end

	def <<(other)
		other = other.__literal_pipeline__ if other.respond_to?(:__literal_pipeline__)

		case other
		when Literal::Seal
			if @coercion
				raise Literal::ArgumentError.new(
					"A coercion cannot run after a seal. Compose as `coercion >> seal` or `seal << coercion` instead.",
				)
			end

			Literal::Seal.new(__compose__(other.seal_proc, @callable), coercion: other.coercion_proc)
		when Literal::Coercion
			Literal::Seal.new(@callable, coercion: @coercion ? __compose__(other.coercion_proc, @coercion) : other.coercion_proc)
		else
			preceding = __proc_from__(other)
			Literal::Seal.new(@callable, coercion: @coercion ? __compose__(preceding, @coercion) : preceding)
		end
	end

	private

	def __proc_from__(callable)
		case callable
		when ::Proc
			callable
		else
			callable.respond_to?(:to_proc) ? callable.to_proc : proc { |value| callable.call(value) }
		end
	end

	def __compose__(first, second)
		proc { |value| second.call(first.call(value)) }
	end
end
