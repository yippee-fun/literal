# frozen_string_literal: true

# An absolute duration of time with nanosecond precision
class Literal::Duration < Literal::Data
	include Comparable

	prop :ns, Integer, default: 0

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

	def inspect
		"Literal::Duration(#{to_human})"
	end

	def to_human
		normalize.map { |unit, count|
			"#{count} #{(count.abs == 1) ? unit.name[0..-2] : unit}"
		}.join(", ")
	end

	def normalize
		microseconds, nanoseconds = divmod_toward_zero(@ns, 1_000)
		milliseconds, microseconds = divmod_toward_zero(microseconds, 1_000)
		seconds, milliseconds = divmod_toward_zero(milliseconds, 1_000)
		minutes, seconds = divmod_toward_zero(seconds, Literal::Temporal::SECONDS_IN_A_MINUTE)
		hours, minutes = divmod_toward_zero(minutes, Literal::Temporal::MINUTES_IN_AN_HOUR)

		[
			([:hours, hours] if hours != 0),
			([:minutes, minutes] if minutes != 0),
			([:seconds, seconds] if seconds != 0),
			([:milliseconds, milliseconds] if milliseconds != 0),
			([:microseconds, microseconds] if microseconds != 0),
			([:nanoseconds, nanoseconds] if nanoseconds != 0),
		].compact.to_h
	end

	private def divmod_toward_zero(value, divisor)
		if value < 0
			quotient, remainder = (-value).divmod(divisor)
			[-quotient, -remainder]
		else
			value.divmod(divisor)
		end
	end
end
