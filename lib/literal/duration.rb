# frozen_string_literal: true

class Literal::Duration < Literal::Object
	prop :years, Integer, reader: :public, default: 0
	prop :months, Integer, reader: :public, default: 0
	prop :weeks, Integer, reader: :public, default: 0
	prop :days, Integer, reader: :public, default: 0

	#: (Literal::Duration) -> Literal::Duration
	def +(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				years: @years + other.years,
				months: @months + other.months,
				weeks: @weeks + other.weeks,
				days: @days + other.days,
			)
		else
			raise ArgumentError
		end
	end

	#: (Literal::Duration) -> Literal::Duration
	def -(other)
		case other
		when Literal::Duration
			Literal::Duration.new(
				years: @years - other.years,
				months: @months - other.months,
				weeks: @weeks - other.weeks,
				days: @days - other.days,
			)
		else
			raise ArgumentError
		end
	end
end
