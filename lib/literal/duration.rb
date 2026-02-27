# frozen_string_literal: true

# A specific duration of time.
class Literal::Duration < Literal::Data
	include Comparable

	prop :nanoseconds, Integer, reader: :public, default: 0

	#: () -> Integer
	def to_i
		@nanoseconds / 1_000_000_000
	end

	alias_method :seconds, :to_i

	#: () -> Rational
	def subseconds
		Rational(@nanoseconds % 1_000_000_000, 1_000_000_000)
	end

	#: (Literal::Duration, Literal::Duration) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Float
	def to_f
		@nanoseconds / 1_000_000_000.0
	end

	#: (Literal::Duration) -> -1 | 0 | 1
	def <=>(other)
		case other
		in Literal::Duration
			@nanoseconds <=> other.nanoseconds
		end
	end

	#: (Literal::Duration | Integer) -> Literal::Duration
	def +(other)
		case other
		in Integer
			Literal::Duration.new(
				nanoseconds: @nanoseconds + (other * 1_000_000_000)
			)
		in Literal::Duration
			Literal::Duration.new(
				nanoseconds: @nanoseconds + other.nanoseconds
			)
		end
	end

	#: (Literal::Duration | Integer) -> Literal::Duration
	def -(other)
		case other
		in Integer
			Literal::Duration.new(
				nanoseconds: @nanoseconds - (other * 1_000_000_000)
			)
		in Literal::Duration
			Literal::Duration.new(
				nanoseconds: @nanoseconds - other.nanoseconds
			)
		end
	end

	#: () -> Literal::Duration
	def -@
		Literal::Duration.new(
			nanoseconds: -@nanoseconds
		)
	end

	#: (nanoseconds: Integer) -> Literal::Duration
	def with(nanoseconds: @nanoseconds)
		Literal::Duration.new(nanoseconds:)
	end

	#: (Literal::Duration) -> bool
	def equals(other)
		self == other
	end
end
