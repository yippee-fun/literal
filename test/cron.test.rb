# frozen_string_literal: true

test "cron parse builds recurrence and dumps canonical expression" do
	start = Time.new(2025, 1, 1, 0, 0, 0, 0)
	recurrence = Literal::Cron.parse("*/15 9-17 * * 1,3,5", start:)

	assert_equal :minutely, recurrence.rule.frequency
	assert_equal 1, recurrence.rule.interval
	assert_equal [0], recurrence.rule.by_second
	assert_equal [0, 15, 30, 45], recurrence.rule.by_minute
	assert_equal [9, 10, 11, 12, 13, 14, 15, 16, 17], recurrence.rule.by_hour
	assert_equal [1, 3, 5], recurrence.rule.by_day_of_week
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0), recurrence.start
	assert_equal "0,15,30,45 9,10,11,12,13,14,15,16,17 * * 1,3,5", recurrence.to_cron
end

test "cron parser supports names and macros" do
	start = Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0)
	named = Literal::Cron.parse("*/10 8-12 * jan,mar mon-fri", start:)
	daily = Literal::Cron.parse("@daily", start:)

	assert_equal [1, 3], named.rule.by_month
	assert_equal [1, 2, 3, 4, 5], named.rule.by_day_of_week
	assert_equal [0, 10, 20, 30, 40, 50], named.rule.by_minute
	assert_equal [8, 9, 10, 11, 12], named.rule.by_hour

	assert_equal [0], daily.rule.by_minute
	assert_equal [0], daily.rule.by_hour
	assert_equal "0 0 * * *", daily.to_cron
end

test "cron day-of-month and day-of-week uses OR semantics" do
	start = Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0)
	recurrence = Literal::Cron.parse("0 9 1 * 1", start:)

	assert recurrence.include?(Literal::LocalDateTime.new(year: 2025, month: 7, day: 1, hour: 9, minute: 0))
	assert recurrence.include?(Literal::LocalDateTime.new(year: 2025, month: 7, day: 7, hour: 9, minute: 0))
	refute recurrence.include?(Literal::LocalDateTime.new(year: 2025, month: 7, day: 8, hour: 9, minute: 0))
end

test "cron parser normalizes sunday 7 to 0" do
	start = Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0)
	recurrence = Literal::Cron.parse("0 9 * * 7", start:)

	assert_equal [0], recurrence.rule.by_day_of_week
	assert recurrence.include?(Literal::LocalDateTime.new(year: 2025, month: 1, day: 5, hour: 9, minute: 0))
end

test "cron dump rejects unsupported recurrence shapes" do
	recurrence = Literal::Recurrence.new(
		start: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0),
		rule: Literal::RecurrenceRule.new(frequency: :hourly, interval: 2, by_minute: [5])
	)

	refute Literal::Cron.representable?(recurrence)
	assert_raises(ArgumentError) { Literal::Cron.dump(recurrence) }
end

test "cron parser validates unsupported or invalid syntax" do
	start = Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 0)

	assert_raises(ArgumentError) { Literal::Cron.parse("@reboot", start:) }
	assert_raises(ArgumentError) { Literal::Cron.parse("0 0 *", start:) }
	assert_raises(ArgumentError) { Literal::Cron.parse("*/0 * * * *", start:) }
	assert_raises(ArgumentError) { Literal::Cron.parse("0 0 * foo *", start:) }
end

test "recurrence next and previous from cron" do
	start = Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9)
	recurrence = Literal::Cron.parse("*/15 9-10 * * *", start:)

	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 15), recurrence.next(after: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 7))
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 15), recurrence.succ(after: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 7))
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 0), recurrence.previous(before: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 7))
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 15), recurrence.next(after: Time.new(2025, 1, 1, 9, 7, 0, 0))
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 0), recurrence.previous(before: "2025-01-01T09:07:00")
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 0), recurrence.pred(before: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 7))
	assert_equal nil, recurrence.previous(before: start)
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 2, hour: 9, minute: 0), recurrence.next(after: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10, minute: 59))
end

test "recurrence next and previous respect count exdates and rdates" do
	recurrence = Literal::Recurrence.new(
		start: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9),
		rule: Literal::RecurrenceRule.new(frequency: :hourly),
		count: 3,
		exdates: [Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10)],
		rdates: [Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10, minute: 30)]
	)

	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10, minute: 30), recurrence.next(after: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 9, minute: 15))
	assert_equal Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10, minute: 30), recurrence.previous(before: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 10, minute: 45))
	assert_equal nil, recurrence.next(after: Literal::LocalDateTime.new(year: 2025, month: 1, day: 1, hour: 11))
end
