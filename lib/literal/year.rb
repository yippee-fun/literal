# frozen_string_literal: true

class Literal::Year < Literal::Object
	prop :year, Integer

	private def after_initialize
		freeze
	end

	#: () -> Integer
	def __year__
		@year
	end

	#: () -> Literal::Year
	def next_year
		self.class.new(year: @year + 1)
	end

	alias_method :succ, :next_year

	#: () -> Literal::Year
	def prev_year
		self.class.new(year: @year - 1)
	end

	#: () -> -1 | 0 | 1
	def <=>(other)
		case other
		when self.class
			@year <=> other.__year__
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::Month
	def first_month
		Literal::Month.new(year: @year, month: 1)
	end

	#: () -> Literal::Month
	def last_month
		Literal::Month.new(year: @year, month: 12)
	end

	#: () -> Range[Literal::Month]
	def months
		(first_month..last_month)
	end

	#: () { (Literal::Month) -> void } -> void
	def each_month(&)
		i = 1
		while i <= 12
			yield Literal::Month.new(year: @year, month: i)
			i += 1
		end
	end
end
