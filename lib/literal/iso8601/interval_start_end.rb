# frozen_string_literal: true

class Literal::ISO8601::IntervalStartEnd < Literal::ISO8601::Node
	prop :start, Literal::ISO8601::IntervalEndpoint
	prop :ending, Literal::ISO8601::IntervalEndpoint

	def iso8601
		"#{@start.iso8601}/#{@ending.iso8601}"
	end

	def valid?
		@start.valid? && @ending.valid?
	end

	alias_method :to_s, :iso8601
end
