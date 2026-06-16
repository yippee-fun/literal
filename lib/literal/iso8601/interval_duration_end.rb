# frozen_string_literal: true

class Literal::ISO8601::IntervalDurationEnd < Literal::ISO8601::Node
	prop :duration, Literal::ISO8601::Duration
	prop :ending, Literal::ISO8601::IntervalEndpoint

	def iso8601
		"#{@duration.iso8601}/#{@ending.iso8601}"
	end

	def valid?
		@duration.valid? && @ending.valid?
	end

	alias_method :to_s, :iso8601
end
