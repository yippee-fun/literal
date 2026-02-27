# frozen_string_literal: true

class Literal::RecurrenceRule < Literal::Data
	Frequencies = _Union(
		:secondly,
		:minutely,
		:hourly,
		:daily,
		:weekly,
		:monthly,
		:yearly
	)

	prop :frequency, Frequencies
	prop :interval, Integer
	prop :by_second, _Array(_Integer(0..59)), default: -> { [] }
	prop :by_minute, _Array(_Integer(0..59)), default: -> { [] }
	prop :by_hour, _Array(_Integer(0..23)), default: -> { [] }
	prop :by_day_of_month, _Array(_Integer(1..31)), default: -> { [] }
	prop :by_month, _Array(_Integer(1..12)), default: -> { [] }
	prop :by_day_of_week, _Array(_Integer(0..6)), default: -> { [] }

	def initialize(
		frequency:,
		interval: 1,
		by_second: [],
		by_minute: [],
		by_hour: [],
		by_day_of_month: [],
		by_month: [],
		by_day_of_week: []
	)
		super
	end

	#: () -> void
	private def after_initialize
		raise ArgumentError unless @interval > 0
	end

	#: (Literal::LocalDateTime | Literal::ZonedDateTime | Literal::LocalDate | Date | Time | String) -> bool
	def matches?(value)
		begin
			value = Literal::LocalDateTime.coerce(value)
		rescue ArgumentError
			return false
		end

		return false if @by_second.any? && !@by_second.include?(value.second)
		return false if @by_minute.any? && !@by_minute.include?(value.minute)
		return false if @by_hour.any? && !@by_hour.include?(value.hour)
		return false if @by_month.any? && !@by_month.include?(value.month)

		day_of_month_match = @by_day_of_month.include?(value.day)
		day_of_week_match = @by_day_of_week.include?(value.to_date.wday)

		if @by_day_of_month.any? && @by_day_of_week.any?
			return false unless day_of_month_match || day_of_week_match
		elsif @by_day_of_month.any?
			return false unless day_of_month_match
		elsif @by_day_of_week.any?
			return false unless day_of_week_match
		end

		true
	end
end
