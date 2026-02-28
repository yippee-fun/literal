# frozen_string_literal: true

class Literal::ISO8601::Duration < Literal::ISO8601::Node
	UNIT_ORDER_INDEX = {
		years: 0,
		months: 1,
		weeks: 2,
		days: 3,
		hours: 4,
		minutes: 5,
		seconds: 6,
	}.freeze

	prop :sign, Literal::ISO8601::Sign, default: 1
	prop :components, _Array(Literal::ISO8601::DurationComponent)

	def iso8601
		sign = (@sign < 0) ? "-" : ""
		parts = +""
		in_time = false

		@components.each do |component|
			if !in_time && time_component?(component)
				parts << "T"
				in_time = true
			end
			parts << component.iso8601
		end

		"#{sign}P#{parts}"
	end

	def valid?
		@components.length > 0 &&
			@components.all?(&:valid?) &&
			!mixed_week_with_other_units? &&
			ordered_units? &&
			valid_fraction_positions?
	end

	alias_method :to_s, :iso8601

	private def time_component?(component)
		case component.unit
		in :hours | :minutes | :seconds
			true
		else
			false
		end
	end

	private def mixed_week_with_other_units?
		has_week = @components.any? { |component| component.unit == :weeks }
		has_week && @components.length > 1
	end

	private def ordered_units?
		last = -1
		@components.each do |component|
			index = unit_order_index(component.unit)
			return false unless index > last
			last = index
		end
		true
	end

	private def unit_order_index(unit)
		UNIT_ORDER_INDEX.fetch(unit)
	end

	private def valid_fraction_positions?
		@components[0...-1].none? { |component| component.fraction_digits > 0 }
	end
end
