# frozen_string_literal: true

class Literal::ISO8601::IntervalStartDuration < Literal::ISO8601::Node
	prop :start, Literal::ISO8601::IntervalEndpoint
	prop :duration, Literal::ISO8601::Duration

	def iso8601
		"#{@start.iso8601}/#{@duration.iso8601}"
	end

	def valid?
		@start.valid? && @duration.valid?
	end

	alias_method :to_s, :iso8601
end
