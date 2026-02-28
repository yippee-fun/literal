# frozen_string_literal: true

class Literal::ISO8601::TimeOfDay < Literal::ISO8601::Node
	prop :hour, Integer
	prop :minute, Integer, default: 0
	prop :second, Integer, default: 0
	prop :precision, Literal::ISO8601::TimePrecision, default: :hour
	prop :fraction, Integer, default: 0
	prop :fraction_digits, Integer, default: 0
	prop :fraction_unit, Literal::ISO8601::FractionUnit, default: :none
	prop :zone, Literal::ISO8601::ZoneNode

	def iso8601
		base = case @precision
		in :hour
			format("%02d", @hour)
		in :minute
			"#{format('%02d', @hour)}:#{format('%02d', @minute)}"
		else
			"#{format('%02d', @hour)}:#{format('%02d', @minute)}:#{format('%02d', @second)}"
		end

		fraction = Literal::ISO8601::Formatting.format_fraction(@fraction, @fraction_digits)
		fraction = fraction ? ".#{fraction}" : ""
		zone = @zone.respond_to?(:iso8601) ? @zone.iso8601 : ""

		"#{base}#{fraction}#{zone}"
	end

	def valid?
		return false unless @hour >= 0 && @hour <= 24
		return false unless @minute >= 0 && @minute <= 59
		return false unless @second >= 0 && @second <= 59
		return false unless Literal::ISO8601.valid_fraction?(@fraction, @fraction_digits)
		return false unless valid_precision_components?
		return false unless valid_fraction_unit?

		@zone.valid?
	end

	alias_method :to_s, :iso8601

	private def valid_precision_components?
		case @precision
		in :hour
			@minute == 0 && @second == 0 && @hour <= 23
		in :minute
			@second == 0 && (@hour <= 23 || (@hour == 24 && @minute == 0 && @fraction == 0 && @fraction_digits == 0))
		else
			!at_midnight_boundary? || (@minute == 0 && @second == 0 && @fraction == 0 && @fraction_digits == 0)
		end
	end

	private def valid_fraction_unit?
		if @fraction_digits == 0
			@fraction_unit == :none
		else
			@fraction_unit == @precision
		end
	end

	private def at_midnight_boundary?
		@hour == 24
	end
end
