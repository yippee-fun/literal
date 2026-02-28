# frozen_string_literal: true

# A specific duration of time.
class Literal::Duration < Literal::Data
	include Comparable

	prop :ns, Integer, reader: :public, default: 0

	def seconds
		@ns / Literal::Temporal::NANOSECONDS_IN_A_SECOND
	end

	alias_method :to_i, :seconds

	def nanoseconds = @ns

	def subseconds
		Rational(
			@ns % Literal::Temporal::NANOSECONDS_IN_A_SECOND,
			Literal::Temporal::NANOSECONDS_IN_A_SECOND
		)
	end

	def to_f
		seconds.to_f
	end

	def <=>(other)
		case other
		when Literal::Duration
			@ns <=> other.ns
		end
	end

	def +(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				ns: @ns + other.ns
			)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}."
		end
	end

	def -(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				ns: @ns - other.ns
			)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}."
		end
	end

	def -@
		Literal::Duration.new(ns: -@ns)
	end
end
