# frozen_string_literal: true

# Represents a concrete interval on the UTC timeline.
class Literal::Interval < Literal::Data
	prop :from, Literal::Instant
	prop :to, Literal::Instant

	private def after_initialize
		unless @from <= @to
			raise Literal::ArgumentError, "Expected form to be less than to."
		end
	end

	def start_time(time_zone)
		Literal::ZonedDateTime.new(
			instant: @from,
			time_zone:
		)
	end

	def duration
		Literal::Duration.new(
			nanoseconds: @to.unix_timestamp_in_nanoseconds - @from.unix_timestamp_in_nanoseconds
		)
	end
end
