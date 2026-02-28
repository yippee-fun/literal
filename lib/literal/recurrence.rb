# frozen_string_literal: true

class Literal::Recurrence < Literal::Data
	Disambiguation = _Union(:earlier, :later, :reject, :compatible)

	prop :start, Literal::PlainDateTime do |value|
		Literal::PlainDateTime.coerce(value)
	end
	prop :rule, Literal::RecurrenceRule
	prop :time_zone, _Nilable(_Deferred { Literal::TimeZone }) do |value|
		if value == nil
			nil
		else
			Literal::NamedTimeZone.coerce(value)
		end
	end
	prop :disambiguation, Disambiguation
	prop :count, _Nilable(Integer)
	prop :until, _Nilable(Literal::PlainDateTime) do |value|
		if value == nil
			nil
		else
			Literal::PlainDateTime.coerce(value)
		end
	end
	prop :exdates, _Array(Literal::PlainDateTime), default: -> { [] } do |value|
		value.map(&Literal::PlainDateTime)
	end
	prop :rdates, _Array(Literal::PlainDateTime), default: -> { [] } do |value|
		value.map(&Literal::PlainDateTime)
	end

	def initialize(
		start:,
		rule:,
		time_zone: nil,
		disambiguation: :compatible,
		count: nil,
		until: nil,
		exdates: [],
		rdates: []
	)
		super
	end

	private def after_initialize
		raise ArgumentError unless @count == nil || @count > 0
		raise ArgumentError unless @until == nil || @start <= @until
	end

	def include?(value)
		begin
			value = Literal::PlainDateTime.coerce(value)
		rescue ArgumentError
			return false
		end

		return false unless in_bounds?(value)
		return false if @exdates.include?(value)
		return true if @rdates.include?(value)

		each_generated_occurrence do |occurrence|
			return true if occurrence == value
			return false if occurrence > value
		end

		false
	end

	alias_method :cover?, :include?
	alias_method :===, :include?

	def next(after:)
		after = Literal::PlainDateTime.coerce(after)

		from_generated = nil
		each_generated_occurrence do |occurrence|
			next unless occurrence > after
			next if @exdates.include?(occurrence)

			from_generated = occurrence
			break
		end

		from_rdates = @rdates.select do |occurrence|
			in_bounds?(occurrence) && occurrence > after && !@exdates.include?(occurrence)
		end.min

		if from_generated && from_rdates
			(from_generated < from_rdates) ? from_generated : from_rdates
		else
			from_generated || from_rdates
		end
	end

	def previous(before:)
		before = Literal::PlainDateTime.coerce(before)

		from_generated = nil
		each_generated_occurrence do |occurrence|
			break if occurrence >= before
			next if @exdates.include?(occurrence)

			from_generated = occurrence
		end

		from_rdates = @rdates.select do |occurrence|
			in_bounds?(occurrence) && occurrence < before && !@exdates.include?(occurrence)
		end.max

		if from_generated && from_rdates
			(from_generated > from_rdates) ? from_generated : from_rdates
		else
			from_generated || from_rdates
		end
	end

	alias_method :succ, :next
	alias_method :pred, :previous

	def to_cron
		Literal::Cron.dump(self)
	end

	private def in_bounds?(value)
		value >= @start && (@until == nil || value <= @until)
	end

	private def each_generated_occurrence
		occurrence = @start
		count = 0
		period = step_period

		loop do
			break if @until && occurrence > @until

			if @rule.matches?(occurrence)
				count += 1
				yield occurrence
				break if @count && count >= @count
			end

			occurrence += period
		end
	end

	private def step_period
		case @rule.frequency
		in :secondly
			Literal::DatePeriod.new(seconds: @rule.interval)
		in :minutely
			Literal::DatePeriod.new(minutes: @rule.interval)
		in :hourly
			Literal::DatePeriod.new(hours: @rule.interval)
		in :daily
			Literal::DatePeriod.new(days: @rule.interval)
		in :weekly
			Literal::DatePeriod.new(weeks: @rule.interval)
		in :monthly
			Literal::DatePeriod.new(months: @rule.interval)
		in :yearly
			Literal::DatePeriod.new(years: @rule.interval)
		end
	end
end
