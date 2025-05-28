# frozen_string_literal: true

class Literal::Year < Literal::Object
	prop :year, Integer

	private def after_initialize
		freeze
	end

	#: (year: Integer) -> bool
	def self.leap_year?(year:)
		year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
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

	#: () -> Literal::Month
	def january
		Literal::Month.new(year: @year, month: 1)
	end

	#: () -> Literal::Month
	def february
		Literal::Month.new(year: @year, month: 2)
	end

	#: () -> Literal::Month
	def march
		Literal::Month.new(year: @year, month: 3)
	end

	#: () -> Literal::Month
	def april
		Literal::Month.new(year: @year, month: 4)
	end

	#: () -> Literal::Month
	def may
		Literal::Month.new(year: @year, month: 5)
	end

	#: () -> Literal::Month
	def june
		Literal::Month.new(year: @year, month: 6)
	end

	#: () -> Literal::Month
	def july
		Literal::Month.new(year: @year, month: 7)
	end

	#: () -> Literal::Month
	def august
		Literal::Month.new(year: @year, month: 8)
	end

	#: () -> Literal::Month
	def september
		Literal::Month.new(year: @year, month: 9)
	end

	#: () -> Literal::Month
	def october
		Literal::Month.new(year: @year, month: 10)
	end

	#: () -> Literal::Month
	def november
		Literal::Month.new(year: @year, month: 11)
	end

	#: () -> Literal::Month
	def december
		Literal::Month.new(year: @year, month: 12)
	end

	#: () -> bool
	def leap_year?
		self.class.leap_year?(year: @year)
	end
end
