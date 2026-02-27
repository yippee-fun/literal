# frozen_string_literal: true

require "date"

class Literal::LocalDate < Literal::Data
	include Comparable

	DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].freeze
	SHORT_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].freeze
	ISO8601_PATTERN = /\A(-?\d{1,})-(\d{2})-(\d{2})\z/

	prop :year, Integer, reader: :public
	prop :month, _Integer(1..12), reader: :public
	prop :day, _Integer(1..31), reader: :public

	#: (String) -> Literal::LocalDate
	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise ArgumentError unless match

		year = Integer(match[1], 10)
		month = Integer(match[2], 10)
		day = Integer(match[3], 10)

		new(year:, month:, day:)
	end

	#: (Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Date | Time | String) -> Literal::LocalDate
	def self.coerce(value)
		case value
		when Literal::LocalDate
			value
		when Literal::LocalDateTime, Literal::ZonedDateTime
			value.to_local_date
		when Date, Time
			new(year: value.year, month: value.month, day: value.day)
		when String
			parse(value)
		else
			raise ArgumentError
		end
	end

	#: () -> Proc
	def self.to_proc
		method(:coerce).to_proc
	end

	#: (Literal::LocalDate, Literal::LocalDate) -> -1 | 0 | 1
	def self.compare(one, two)
		one <=> two
	end

	# Returns an Integer between 0 and 6, where 0 is Sunday.
	#: (year: Integer, month: Integer, day: Integer) -> Integer
	def self.zellers_congruence(year:, month:, day:)
		year, month, day = adjusted_date_for_zeller(year:, month:, day:)

		q = day
		m = month
		k = year % 100
		j = year / 100

		(q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
	end

	#: (year: Integer, month: Integer, day: Integer) -> [Integer, Integer, Integer]
	private_class_method def self.adjusted_date_for_zeller(year:, month:, day:)
		if month < 3
			month += 12
			year -= 1
		end

		[year, month, day].freeze
	end

	#: () -> void
	private def after_initialize
		unless @day <= Literal::LocalMonth.days_in_month(year: @year, month: @month)
			raise ArgumentError
		end
	end

	#: () -> String
	def name
		DAY_NAMES[day_of_week_index]
	end

	#: () -> String
	def short_name
		SHORT_DAY_NAMES[day_of_week_index]
	end

	#: () -> Integer
	def day_of_year
		day_of_year = @day

		month = 1
		while month < @month
			day_of_year += Literal::LocalMonth.days_in_month(year: @year, month:)
			month += 1
		end

		day_of_year
	end

	#: () -> Integer
	def day_of_month
		@day
	end

	# Return the day of week from 1 to 7, starting on Monday.
	#: () -> Integer
	def day_of_week
		day_of_week_index + 1
	end

	#: () -> Literal::LocalDate
	def next_day
		days_in_month = Literal::LocalMonth.days_in_month(year: @year, month: @month)

		if @day < days_in_month
			Literal::LocalDate.new(year: @year, month: @month, day: @day + 1)
		elsif @month < 12
			Literal::LocalDate.new(year: @year, month: @month + 1, day: 1)
		else
			Literal::LocalDate.new(year: @year + 1, month: 1, day: 1)
		end
	end

	alias_method :succ, :next_day

	#: () -> Literal::LocalDate
	def prev_day
		if @day > 1
			Literal::LocalDate.new(
				year: @year,
				month: @month,
				day: @day - 1
			)
		elsif @month > 1
			Literal::LocalDate.new(
				year: @year,
				month: @month - 1,
				day: Literal::LocalMonth.days_in_month(year: @year, month: @month - 1)
			)
		else
			Literal::LocalDate.new(
				year: @year - 1,
				month: 12,
				day: Literal::LocalMonth.days_in_month(year: @year - 1, month: 12)
			)
		end
	end

	alias_method :pred, :prev_day

	#: (Literal::LocalDate) -> -1 | 0 | 1 | nil
	def <=>(other)
		case other
		when Literal::LocalDate
			[@year, @month, @day] <=> [other.year, other.month, other.day]
		end
	end

	#: () -> bool
	def monday?
		0 == day_of_week_index
	end

	#: () -> bool
	def tuesday?
		1 == day_of_week_index
	end

	#: () -> bool
	def wednesday?
		2 == day_of_week_index
	end

	#: () -> bool
	def thursday?
		3 == day_of_week_index
	end

	#: () -> bool
	def friday?
		4 == day_of_week_index
	end

	#: () -> bool
	def saturday?
		5 == day_of_week_index
	end

	#: () -> bool
	def sunday?
		6 == day_of_week_index
	end

	#: () -> Literal::LocalMonth
	def to_month
		Literal::LocalMonth.new(year: @year, month: @month)
	end

	#: () -> Date
	def to_date
		Date.new(@year, @month, @day)
	end

	#: () -> Literal::YearMonth
	def to_year_month
		Literal::YearMonth.new(year: @year, month: @month)
	end

	#: () -> Literal::MonthDay
	def to_month_day
		Literal::MonthDay.new(month: @month, day: @day)
	end

	#: () -> String
	def iso8601
		"#{@year}-#{format('%02d', @month)}-#{format('%02d', @day)}"
	end

	alias_method :to_s, :iso8601

	#: (?year: Integer, ?month: Integer, ?day: Integer) -> Literal::LocalDate
	def with(year: @year, month: @month, day: @day)
		Literal::LocalDate.new(year:, month:, day:)
	end

	#: (Literal::LocalDate) -> bool
	def equals(other)
		self == other
	end

	#: (Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Date | Time | String) -> Literal::DatePeriod
	def since(other)
		other = Literal::LocalDate.coerce(other)

		Literal::DatePeriod.new(days: (to_date - other.to_date).to_i)
	end

	#: (Literal::LocalDate | Literal::LocalDateTime | Literal::ZonedDateTime | Date | Time | String) -> Literal::DatePeriod
	def until(other)
		Literal::LocalDate.coerce(other).since(self)
	end

	#: () -> Literal::LocalYear
	def to_year
		Literal::LocalYear.new(year: @year)
	end

	#: (Literal::LocalTime | Literal::LocalDateTime | Literal::ZonedDateTime | Time | String | nil, **Integer) -> Literal::LocalDateTime
	def at(local_time = nil, **parts)
		if local_time && parts.any?
			raise ArgumentError
		end

		local_time = if local_time
			Literal::LocalTime.coerce(local_time)
		else
			Literal::LocalTime.new(**parts)
		end

		local_time.to_local_date_time(self)
	end

	#: () -> bool
	def weekend?
		day_of_week_index > 4
	end

	#: () -> bool
	def weekday?
		day_of_week_index < 5
	end

	#: (Literal::DatePeriod) -> Literal::LocalDate
	def +(other)
		case other
		when Literal::DatePeriod
			if other.hours != 0 || other.nanoseconds != 0
				raise ArgumentError
			end

			date_time = Literal::LocalDateTime.new(year: @year, month: @month, day: @day)
			result = date_time + other
			Literal::LocalDate.new(year: result.year, month: result.month, day: result.day)
		else
			raise ArgumentError
		end
	end

	#: (Literal::DatePeriod) -> Literal::LocalDate
	def -(other)
		case other
		when Literal::DatePeriod
			self + (-other)
		else
			raise ArgumentError
		end
	end

	#: () -> Literal::LocalDate
	def next_monday
		next_day_of_week(0)
	end

	#: () -> Literal::LocalDate
	def next_tuesday
		next_day_of_week(1)
	end

	#: () -> Literal::LocalDate
	def next_wednesday
		next_day_of_week(2)
	end

	#: () -> Literal::LocalDate
	def next_thursday
		next_day_of_week(3)
	end

	#: () -> Literal::LocalDate
	def next_friday
		next_day_of_week(4)
	end

	#: () -> Literal::LocalDate
	def next_saturday
		next_day_of_week(5)
	end

	#: () -> Literal::LocalDate
	def next_sunday
		next_day_of_week(6)
	end

	#: () -> Literal::LocalDate
	def prev_monday
		prev_day_of_week(0)
	end

	#: () -> Literal::LocalDate
	def prev_tuesday
		prev_day_of_week(1)
	end

	#: () -> Literal::LocalDate
	def prev_wednesday
		prev_day_of_week(2)
	end

	#: () -> Literal::LocalDate
	def prev_thursday
		prev_day_of_week(3)
	end

	#: () -> Literal::LocalDate
	def prev_friday
		prev_day_of_week(4)
	end

	#: () -> Literal::LocalDate
	def prev_saturday
		prev_day_of_week(5)
	end

	#: () -> Literal::LocalDate
	def prev_sunday
		prev_day_of_week(6)
	end

	#: () { (Literal::LocalDateTime) -> void } -> void
	def each_hour
		return enum_for(__method__) { 24 } unless block_given?

		hour = 0
		while hour < 24
			yield Literal::LocalDateTime.new(year: @year, month: @month, day: @day, hour:)
			hour += 1
		end
	end

	#: () { (Literal::LocalDateTime) -> void } -> void
	def each_minute
		return enum_for(__method__) { 1_440 } unless block_given?

		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				yield Literal::LocalDateTime.new(year: @year, month: @month, day: @day, hour:, minute:)
				minute += 1
			end
			hour += 1
		end
	end

	#: () { (Literal::LocalDateTime) -> void } -> void
	def each_second
		return enum_for(__method__) { 86_400 } unless block_given?

		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				second = 0
				while second < 60
					yield Literal::LocalDateTime.new(year: @year, month: @month, day: @day, hour:, minute:, second:)
					second += 1
				end
				minute += 1
			end
			hour += 1
		end
	end

	# Return the day of the week as an integer from 0 to 6 but where the 0th is Monday.
	#: () -> Integer
	private def day_of_week_index
		(self.class.zellers_congruence(year: @year, month: @month, day: @day) + 5) % 7
	end

	#: (Integer) -> Literal::LocalDate
	private def next_day_of_week(target_day_index)
		days_until_target = (target_day_index + 7 - day_of_week_index) % 7
		days_until_target = 7 if days_until_target == 0
		self + Literal::DatePeriod.new(days: days_until_target)
	end

	#: (Integer) -> Literal::LocalDate
	private def prev_day_of_week(target_day_index)
		days_until_target = (day_of_week_index - target_day_index) % 7
		days_until_target = 7 if days_until_target == 0
		self - Literal::DatePeriod.new(days: days_until_target)
	end
end
