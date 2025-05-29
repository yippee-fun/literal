# frozen_string_literal: true

# Represents an abstract period of time between two abstract times
class Literal::Period < Literal::Object
	prop :from, Literal::Time, reader: :public
	prop :to, Literal::Time, reader: :public

	#: () -> void
	private def after_initialize
		unless @from <= @to
			raise ArgumentError
		end

		freeze
	end

	#: () -> Literal::Duration
	def duration
		Literal::Duration.new(
			years: @to.year - @from.year,
			months: @to.month - @from.month,
			days: @to.day - @from.day,
			hours: @to.hour - @from.hour,
			minutes: @to.minutes - @from.minutes,
			seconds: @to.seconds - @from.seconds,
			milliseconds: @to.milliseconds - @from.milliseconds,
			microseconds: @to.microseconds - @from.microseconds,
			nanoseconds: @to.nanoseconds - @from.nanoseconds
		)
	end

	def every(step, unit, &block)
		enumerator = Literal::TimeEnumerator.new(
			from: @from,
			to: @to,
			unit:,
			step:
		)

		block ? enumerator.each(&block) : enumerator
	end
end
