# frozen_string_literal: true

class Literal::LocalDateTimeRange < Literal::Data
	include Comparable

	prop :from, Literal::LocalDateTime
	prop :to, Literal::LocalDateTime

	#: () -> void
	private def after_initialize
		raise ArgumentError unless @from <= @to
	end

	#: (Literal::LocalDateTime) -> bool
	def include?(value)
		case value
		when Literal::LocalDateTime
			@from <= value && value <= @to
		else
			false
		end
	end

	alias_method :cover?, :include?

	#: (Literal::LocalDateTimeRange) -> bool
	def overlaps?(other)
		other => Literal::LocalDateTimeRange
		@from <= other.to && other.from <= @to
	end

	#: (Literal::LocalDateTimeRange) -> Literal::LocalDateTimeRange?
	def intersection(other)
		other => Literal::LocalDateTimeRange
		return nil unless overlaps?(other)

		Literal::LocalDateTimeRange.new(
			from: ((@from >= other.from) ? @from : other.from),
			to: ((@to <= other.to) ? @to : other.to)
		)
	end

	#: (Literal::TimeZone | String, disambiguation: Symbol) -> Literal::Interval
	def in_zone(time_zone, disambiguation: :compatible)
		start = @from.in_zone(time_zone, disambiguation:)
		finish = @to.in_zone(time_zone, disambiguation:)

		Literal::Interval.new(from: start.to_instant, to: finish.to_instant)
	end

	#: (Literal::LocalDateTimeRange) -> -1 | 0 | 1
	def <=>(other)
		other => Literal::LocalDateTimeRange

		result = @from <=> other.from
		return result unless result == 0
		@to <=> other.to
	end

	#: () -> String
	def to_s
		"#{@from.iso8601}..#{@to.iso8601}"
	end
end
