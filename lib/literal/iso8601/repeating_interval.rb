# frozen_string_literal: true

class Literal::ISO8601::RepeatingInterval < Literal::ISO8601::Node
	prop :repetitions, Integer, default: -1
	prop :interval, Literal::ISO8601::IntervalNode

	def iso8601
		repetitions = (@repetitions < 0) ? "" : @repetitions.to_s
		"R#{repetitions}/#{@interval.iso8601}"
	end

	def valid?
		(@repetitions == -1 || @repetitions >= 0) && @interval.valid?
	end

	alias_method :to_s, :iso8601
end
