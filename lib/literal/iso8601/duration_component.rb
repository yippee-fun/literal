# frozen_string_literal: true

class Literal::ISO8601::DurationComponent < Literal::ISO8601::Node
	UNIT_DESIGNATORS = {
		years: "Y",
		months: "M",
		weeks: "W",
		days: "D",
		hours: "H",
		minutes: "M",
		seconds: "S",
	}.freeze

	prop :unit, Literal::ISO8601::DurationUnit
	prop :value, Integer
	prop :fraction, Integer, default: 0
	prop :fraction_digits, Integer, default: 0

	def iso8601
		fraction = Literal::ISO8601::Formatting.format_fraction(@fraction, @fraction_digits)
		fraction = fraction ? ".#{fraction}" : ""
		"#{@value}#{fraction}#{unit_designator}"
	end

	def valid?
		@value >= 0 && Literal::ISO8601.valid_fraction?(@fraction, @fraction_digits)
	end

	alias_method :to_s, :iso8601

	private def unit_designator
		UNIT_DESIGNATORS.fetch(@unit)
	end
end
