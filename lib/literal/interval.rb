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
		Literal::Duration.new(
			nanoseconds: @to.unix_timestamp_in_nanoseconds - @from.unix_timestamp_in_nanoseconds
		)
	end
end
