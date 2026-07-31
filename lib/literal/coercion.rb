# frozen_string_literal: true

# A composable input coercion. Wraps a callable that normalizes input before
# the type check. Coercions run at the input boundaries — the initializer,
# writers, and draft assignment — and never on final-value paths like
# `from_props` or `marshal_load`.
#
# Compose with `>>` and `<<`: composing two coercions returns a coercion, and
# composing with a `Literal::Seal` returns a seal whose coercion runs first.
# A coercion can never come after a seal.
#
# Construct with `Literal::Coercion(&block)`.
class Literal::Coercion
	class << self
		def [](...)
			new(...)
		end
	end

	def initialize(callable = nil, &block)
		callable ||= block

		unless callable
			raise Literal::ArgumentError.new("Literal::Coercion requires a callable or a block.")
		end

		@callable = __proc_from__(callable)

		pipeline = self
		@proc = proc { |value| pipeline.call(value) }
		@proc.define_singleton_method(:__literal_pipeline__) { pipeline }

		freeze
	end

	# The coercion as a Proc, for property definitions — `prop :name, String, &NilIfEmpty`.
	# The returned proc carries a reference back to this object, so `prop` can
	# recover the pipeline structure.
	def to_proc
		@proc
	end

	def call(value)
		@callable.call(value)
	end

	def coercion_proc
		@callable
	end

	def seal_proc
		nil
	end

	def >>(other)
		other = other.__literal_pipeline__ if other.respond_to?(:__literal_pipeline__)

		case other
		when Literal::Seal
			Literal::Seal.new(
				other.seal_proc,
				coercion: (coercion = other.coercion_proc) ? __compose__(@callable, coercion) : @callable,
			)
		when Literal::Coercion
			Literal::Coercion.new(__compose__(@callable, other.coercion_proc))
		else
			Literal::Coercion.new(__compose__(@callable, __proc_from__(other)))
		end
	end

	def <<(other)
		other = other.__literal_pipeline__ if other.respond_to?(:__literal_pipeline__)

		case other
		when Literal::Seal
			raise Literal::ArgumentError.new(
				"A coercion cannot run after a seal. Compose as `coercion >> seal` or `seal << coercion` instead.",
			)
		when Literal::Coercion
			Literal::Coercion.new(__compose__(other.coercion_proc, @callable))
		else
			Literal::Coercion.new(__compose__(__proc_from__(other), @callable))
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
