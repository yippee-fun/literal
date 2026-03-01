# frozen_string_literal: true

require "date"

class Literal::PlainDate < Literal::Data
	include Comparable

	prop :year, Integer
	prop :month, _Integer(1..12)
	prop :day, _Integer(1..31)

	def after_initialize
		unless @day <= Literal::PlainYearMonth.days_in_month(year: @year, month: @month)
			raise Literal::ArgumentError, "Invalid date: #{inspect}"
		end
	end

	def self.parse(value)
		node = Literal::ISO8601.try_parse_valid_date(value)

		if Literal::ISO8601::CalendarDate === node
			new(year: node.year, month: node.month, day: node.day)
		else
			raise Literal::ArgumentError, "Invalid ISO 8601 local date: #{value.inspect}"
		end
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

	def name
		Literal::Temporal::DAY_NAMES.fetch(current_day_of_week_index)
	end

	def short_name
		Literal::Temporal::SHORT_DAY_NAMES.fetch(current_day_of_week_index)
	end

	def day_of_year
		Literal::Temporal.day_of_year(year: @year, month: @month, day: @day)
	end

	def day_of_month
		@day
	end

	# Return the day of week from 1 to 7, starting on Monday.
	def day_of_week
		current_day_of_week_index + 1
	end

	def next_day
		days_in_month = Literal::Temporal.days_in_month(year: @year, month: @month)

		if @day < days_in_month
			Literal::PlainDate.new(year: @year, month: @month, day: @day + 1)
		elsif @month < 12
			Literal::PlainDate.new(year: @year, month: @month + 1, day: 1)
		else
			Literal::PlainDate.new(year: @year + 1, month: 1, day: 1)
		end
	end

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
				day: Literal::Temporal.days_in_month(year: @year, month: @month - 1)
			)
		else
			Literal::PlainDate.new(
				year: @year - 1,
				month: 12,
				day: Literal::Temporal.days_in_month(year: @year - 1, month: 12)
			)
		end
	end

	alias_method :succ, :next_day
	alias_method :pred, :prev_day

	def <=>(other)
		case other
		when Literal::PlainDate
			[@year, @month, @day] <=> [other.year, other.month, other.day]
		end
	end

	def monday?
		0 == current_day_of_week_index
	end

	def tuesday?
		1 == current_day_of_week_index
	end

	def wednesday?
		2 == current_day_of_week_index
	end

	def thursday?
		3 == current_day_of_week_index
	end

	def friday?
		4 == current_day_of_week_index
	end

	def saturday?
		5 == current_day_of_week_index
	end

	def sunday?
		6 == current_day_of_week_index
	end

	alias_method :mon?, :monday?
	alias_method :tue?, :tuesday?
	alias_method :wed?, :wednesday?
	alias_method :thu?, :thursday?
	alias_method :fri?, :friday?
	alias_method :sat?, :saturday?
	alias_method :sun?, :sunday?

	def to_year_month
		Literal::PlainYearMonth.new(year: @year, month: @month)
	end

	def to_ruby_date
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

		days = Literal::Temporal.days_since_epoch(year: @year, month: @month, day: @day) -
			Literal::Temporal.days_since_epoch(year: other.year, month: other.month, day: other.day)

		Literal::Period.new(days:)
	end

	def until(other)
		Literal::PlainDate.coerce(other).since(self)
	end

	def to_year
		Literal::PlainYear.new(year: @year)
	end

	def weekend?
		current_day_of_week_index > 4
	end

	def weekday?
		current_day_of_week_index < 5
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
		return enum_for(__method__) { Literal::Temporal::HOURS_IN_A_DAY } unless block_given?

		hour = 0
		while hour < 24
			yield Literal::PlainDateTime.new(year: @year, month: @month, day: @day, hour:)
			hour += 1
		end
	end

	def each_minute
		return enum_for(__method__) { Literal::Temporal::MINUTES_IN_A_DAY } unless block_given?

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
		return enum_for(__method__) { Literal::Temporal::SECONDS_IN_A_DAY } unless block_given?

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

	private def current_day_of_week_index
		Literal::Temporal.day_of_week_index(year: @year, month: @month, day: @day)
	end

	private def next_day_of_week(target_day_index)
		days_until_target = (target_day_index + 7 - current_day_of_week_index) % 7
		days_until_target = 7 if days_until_target == 0
		self + Literal::Period.new(days: days_until_target)
	end

	private def prev_day_of_week(target_day_index)
		days_until_target = (current_day_of_week_index - target_day_index) % 7
		days_until_target = 7 if days_until_target == 0
		self - Literal::Period.new(days: days_until_target)
	end
end
