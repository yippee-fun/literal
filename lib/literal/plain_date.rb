# frozen_string_literal: true

require "date"

class Literal::PlainDate < Literal::Data
	include Comparable

	DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].freeze
	SHORT_DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].freeze
	ISO8601_PATTERN = /\A(-?\d{1,})-(\d{2})-(\d{2})\z/

	prop :year, Integer, reader: :public
	prop :month, _Integer(1..12), reader: :public
	prop :day, _Integer(1..31), reader: :public

	def self.parse(value)
		match = ISO8601_PATTERN.match(value)
		raise Literal::ArgumentError, "Invalid ISO 8601 local date: #{value.inspect}" unless match

		year = Integer(match[1], 10)
		month = Integer(match[2], 10)
		day = Integer(match[3], 10)

		new(year:, month:, day:)
	end

	def self.coerce(value)
		case value
		when Literal::PlainDate
			value
		when Literal::PlainDateTime, Literal::ZonedDateTime
			value.to_plain_date
		when Date, Time
			new(year: value.year, month: value.month, day: value.day)
		when String
			parse(value)
		else
			raise Literal::ArgumentError, "Can't coerce #{value.inspect} to a Literal::PlainDate"
		end
	end

	def self.to_proc
		method(:coerce).to_proc
	end

	def self.days_since_epoch(year:, month:, day:)
		civil_to_days(year, month, day)
	end

	private_class_method def self.civil_to_days(year, month, day)
		year -= 1 if month <= 2
		era = (year >= 0) ? (year / 400) : ((year - 399) / 400)
		yoe = year - (era * 400)
		mp = month + ((month > 2) ? -3 : 9)
		doy = ((153 * mp) + 2) / 5 + day - 1
		doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy

		(era * 146_097) + doe - 719_468
	end

	# Returns an Integer between 0 and 6, where 0 is Sunday.
	def self.zellers_congruence(year:, month:, day:)
		year, month, day = adjusted_date_for_zeller(year:, month:, day:)

		q = day
		m = month
		k = year % 100
		j = year / 100

		(q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
	end

	private_class_method def self.adjusted_date_for_zeller(year:, month:, day:)
		if month < 3
			month += 12
			year -= 1
		end

		[year, month, day].freeze
	end

	private def after_initialize
		unless @day <= Literal::PlainYearMonth.days_in_month(year: @year, month: @month)
			raise Literal::ArgumentError, "#{@day} is not a valid day for month #{@month} in year #{@year}"
		end
	end

	def name
		DAY_NAMES[day_of_week_index]
	end

	def short_name
		SHORT_DAY_NAMES[day_of_week_index]
	end

	def day_of_year
		day_of_year = @day

		month = 1
		while month < @month
			day_of_year += Literal::PlainYearMonth.days_in_month(year: @year, month:)
			month += 1
		end

		day_of_year
	end

	def day_of_month
		@day
	end

	# Return the day of week from 1 to 7, starting on Monday.
	def day_of_week
		day_of_week_index + 1
	end

	def next_day
		days_in_month = Literal::PlainYearMonth.days_in_month(year: @year, month: @month)

		if @day < days_in_month
			Literal::PlainDate.new(year: @year, month: @month, day: @day + 1)
		elsif @month < 12
			Literal::PlainDate.new(year: @year, month: @month + 1, day: 1)
		else
			Literal::PlainDate.new(year: @year + 1, month: 1, day: 1)
		end
	end

	alias_method :succ, :next_day

	def prev_day
		if @day > 1
			Literal::PlainDate.new(
				year: @year,
				month: @month,
				day: @day - 1
			)
		elsif @month > 1
			Literal::PlainDate.new(
				year: @year,
				month: @month - 1,
				day: Literal::PlainYearMonth.days_in_month(year: @year, month: @month - 1)
			)
		else
			Literal::PlainDate.new(
				year: @year - 1,
				month: 12,
				day: Literal::PlainYearMonth.days_in_month(year: @year - 1, month: 12)
			)
		end
	end

	alias_method :pred, :prev_day

	def <=>(other)
		case other
		when Literal::PlainDate
			[@year, @month, @day] <=> [other.year, other.month, other.day]
		end
	end

	def monday?
		0 == day_of_week_index
	end

	def tuesday?
		1 == day_of_week_index
	end

	def wednesday?
		2 == day_of_week_index
	end

	def thursday?
		3 == day_of_week_index
	end

	def friday?
		4 == day_of_week_index
	end

	def saturday?
		5 == day_of_week_index
	end

	def sunday?
		6 == day_of_week_index
	end

	def to_year_month
		Literal::PlainYearMonth.new(year: @year, month: @month)
	end

	def to_date
		Date.new(@year, @month, @day)
	end

	def to_month_day
		Literal::MonthDay.new(month: @month, day: @day)
	end

	def iso8601
		"#{@year}-#{format('%02d', @month)}-#{format('%02d', @day)}"
	end

	alias_method :to_s, :iso8601

	def since(other)
		other = Literal::PlainDate.coerce(other)

		days = self.class.days_since_epoch(year: @year, month: @month, day: @day) -
			self.class.days_since_epoch(year: other.year, month: other.month, day: other.day)

		Literal::DatePeriod.new(days:)
	end

	def until(other)
		Literal::PlainDate.coerce(other).since(self)
	end

	def to_year
		Literal::PlainYear.new(year: @year)
	end

	def at(local_time = nil, **parts)
		if local_time && parts.any?
			raise Literal::ArgumentError, "Pass either a local_time or keyword parts, not both"
		end

		local_time = if local_time
			Literal::PlainTime.coerce(local_time)
		else
			Literal::PlainTime.new(**parts)
		end

		local_time.to_plain_date_time(self)
	end

	def weekend?
		day_of_week_index > 4
	end

	def weekday?
		day_of_week_index < 5
	end

	def +(other)
		case other
		when Literal::DatePeriod
			if other.hours != 0 || other.nanoseconds != 0
				raise Literal::ArgumentError, "Can't add a Literal::DatePeriod with time components to a Literal::PlainDate"
			end

			date_time = Literal::PlainDateTime.new(year: @year, month: @month, day: @day)
			result = date_time + other
			Literal::PlainDate.new(year: result.year, month: result.month, day: result.day)
		else
			raise Literal::ArgumentError, "Expected a Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def -(other)
		case other
		when Literal::DatePeriod
			self + (-other)
		else
			raise Literal::ArgumentError, "Expected a Literal::DatePeriod, got #{other.inspect}"
		end
	end

	def next_monday
		next_day_of_week(0)
	end

	def next_tuesday
		next_day_of_week(1)
	end

	def next_wednesday
		next_day_of_week(2)
	end

	def next_thursday
		next_day_of_week(3)
	end

	def next_friday
		next_day_of_week(4)
	end

	def next_saturday
		next_day_of_week(5)
	end

	def next_sunday
		next_day_of_week(6)
	end

	def prev_monday
		prev_day_of_week(0)
	end

	def prev_tuesday
		prev_day_of_week(1)
	end

	def prev_wednesday
		prev_day_of_week(2)
	end

	def prev_thursday
		prev_day_of_week(3)
	end

	def prev_friday
		prev_day_of_week(4)
	end

	def prev_saturday
		prev_day_of_week(5)
	end

	def prev_sunday
		prev_day_of_week(6)
	end

	def each_hour
		return enum_for(__method__) { 24 } unless block_given?

		hour = 0
		while hour < 24
			yield Literal::PlainDateTime.new(year: @year, month: @month, day: @day, hour:)
			hour += 1
		end
	end

	def each_minute
		return enum_for(__method__) { 1_440 } unless block_given?

		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				yield Literal::PlainDateTime.new(year: @year, month: @month, day: @day, hour:, minute:)
				minute += 1
			end
			hour += 1
		end
	end

	def each_second
		return enum_for(__method__) { 86_400 } unless block_given?

		hour = 0
		while hour < 24
			minute = 0
			while minute < 60
				second = 0
				while second < 60
					yield Literal::PlainDateTime.new(year: @year, month: @month, day: @day, hour:, minute:, second:)
					second += 1
				end
				minute += 1
			end
			hour += 1
		end
	end

	# Return the day of the week as an integer from 0 to 6 but where the 0th is Monday.
	private def day_of_week_index
		(self.class.zellers_congruence(year: @year, month: @month, day: @day) + 5) % 7
	end

	private def next_day_of_week(target_day_index)
		days_until_target = (target_day_index + 7 - day_of_week_index) % 7
		days_until_target = 7 if days_until_target == 0
		self + Literal::DatePeriod.new(days: days_until_target)
	end

	private def prev_day_of_week(target_day_index)
		days_until_target = (day_of_week_index - target_day_index) % 7
		days_until_target = 7 if days_until_target == 0
		self - Literal::DatePeriod.new(days: days_until_target)
	end

end
