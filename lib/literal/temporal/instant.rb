# frozen_string_literal: true

require "time"

# Models a point in time irrespective of time zone.
class Literal::Instant < Literal::Data
	include Comparable

	# The number of nanoseconds since the Unix Epoch (January 1, 1970, 00:00:00 UTC).
	prop :ns, Integer

	def self.now
		Literal::Instant.new(ns: Literal::Temporal.current_instant_ns)
	end

	def <=>(other)
		case other
		when Literal::Instant
			@ns <=> other.ns
		end
	end

	def -(other)
		case other
		when Literal::Instant
			Literal::Duration.new(ns: @ns - other.ns)
		when Literal::Duration
			Literal::Instant.new(ns: @ns - other.ns)
		else
			raise Literal::ArgumentError, "Expected a Literal::Instant or Literal::Duration, got #{other.inspect}."
		end
	end

	def +(other)
		case other
		when Literal::Duration
			Literal::Instant.new(ns: @ns + other.ns)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}."
		end
	end

	def next_nanosecond
		Literal::Instant.new(ns: @ns + 1)
	end

	def prev_nanosecond
		Literal::Instant.new(ns: @ns - 1)
	end

	alias_method :succ, :next_nanosecond
	alias_method :pred, :prev_nanosecond
end
