# frozen_string_literal: true

class Literal::ISO8601::OffsetZone < Literal::ISO8601::Node
	prop :sign, Literal::ISO8601::Sign
	prop :hours, Integer
	prop :minutes, Integer

	def iso8601
		sign = (@sign < 0) ? "-" : "+"
		"#{sign}#{format('%02d', @hours)}:#{format('%02d', @minutes)}"
	end

	def valid?
		@hours >= 0 && @hours <= 23 && @minutes >= 0 && @minutes <= 59
	end

	alias_method :to_s, :iso8601
end
