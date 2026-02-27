# frozen_string_literal: true

# A specific duration of time.
class Literal::Duration < Literal::Data
	include Comparable

	prop :seconds, Integer, reader: :public, default: 0
	prop :subseconds, Rational, reader: :public, default: Rational(0, 1_000)

	alias_method :to_i, :seconds

	#: (Literal::Duration, Literal::Duration) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	#: () -> Float
	def to_f
		(seconds + subseconds).to_f
	end

	#: (Literal::Duration) -> -1 | 0 | 1
	def <=>(other)
		case other
		in Literal::Duration
			result = @seconds <=> other.seconds
			return result unless result == 0
			@subseconds <=> other.subseconds
		end
	end

	#: (Literal::Duration | Integer) -> Literal::Duration
	def +(other)
		case other
		in Integer
			Literal::Duration.new(
				seconds: @seconds + other,
				subseconds: @subseconds
			)
		in Literal::Duration
			Literal::Duration.new(
				seconds: @seconds + other.seconds,
				subseconds: @subseconds + other.subseconds
			)
		end
	end

	#: (Literal::Duration | Integer) -> Literal::Duration
	def -(other)
		case other
		in Integer
			Literal::Duration.new(
				seconds: @seconds - other,
				subseconds: @subseconds
			)
		in Literal::Duration
			Literal::Duration.new(
				seconds: @seconds - other.seconds,
				subseconds: @subseconds - other.subseconds
			)
		end
	end

	#: () -> Literal::Duration
	def -@
		Literal::Duration.new(
			seconds: -@seconds,
			subseconds: -@subseconds
		)
	end

	#: (seconds: Integer, subseconds: Rational) -> Literal::Duration
	def with(seconds: @seconds, subseconds: @subseconds)
		Literal::Duration.new(seconds:, subseconds:)
	end

	#: (Literal::Duration) -> bool
	def equals(other)
		self == other
	end
end
