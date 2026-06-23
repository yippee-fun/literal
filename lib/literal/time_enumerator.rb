# frozen_string_literal: true

class Literal::TimeEnumerator < Literal::Object
	include Enumerable

	Unit = _Union(
		:centuries,
		:decades,
		:years,
		:quarters,
		:months,
		:fortnights,
		:weeks,
		:days,
		:hours,
		:minutes,
		:seconds,
		:milliseconds,
		:microseconds,
		:nanoseconds
	)

	prop :from, Literal::Time, reader: :public
	prop :to, Literal::Time, reader: :public
	prop :unit, Literal::TimeUnit, reader: :public
	prop :step, Integer, reader: :public

	#: () -> Literal::Period
	def period
		Literal::Period.new(from: @from, to: @to)
	end

	#: () { (Literal::Time) -> void } -> void
	def each
	end
end
