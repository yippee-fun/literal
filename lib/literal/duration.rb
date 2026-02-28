# frozen_string_literal: true

# A specific duration of time.
class Literal::Duration < Literal::Data
	include Comparable

	prop :nanoseconds, Integer, reader: :public, default: 0

	def seconds
		@nanoseconds / 1_000_000_000
	end

	alias_method :to_i, :seconds

	def subseconds
		Rational(@nanoseconds % 1_000_000_000, 1_000_000_000)
	end

	def to_f
		@nanoseconds / 1_000_000_000.0
	end

	def <=>(other)
		case other
		in Literal::Duration
			@nanoseconds <=> other.nanoseconds
		end
	end

	def +(other)
		case other
		in Literal::Duration
			Literal::Duration.new(
				nanoseconds: @nanoseconds + other.nanoseconds
			)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}."
		end
	end

	def -(other)
		case other
		in Literal::Duration
			Literal::Duration.new(
				nanoseconds: @nanoseconds - other.nanoseconds
			)
		else
			raise Literal::ArgumentError, "Expected a Literal::Duration, got #{other.inspect}."
		end
	end

	def -@
		Literal::Duration.new(
			nanoseconds: -@nanoseconds
		)
	end
end
