# frozen_string_literal: true

# Represents a concrete interval on the UTC timeline.
class Literal::Interval < Literal::Data
	prop :from, Literal::Instant
	prop :to, Literal::Instant

	#: () -> void
	private def after_initialize
		unless @from <= @to
			raise ArgumentError
		end
	end

	#: () -> Literal::Duration
	def duration
		seconds = @to.unix_timestamp_in_seconds - @from.unix_timestamp_in_seconds
		subseconds = @to.subsec - @from.subsec

		Literal::Duration.new(
			seconds:,
			subseconds:
		)
	end
end
