# frozen_string_literal: true

test "local date time resolution disambiguation" do
	zone = Literal::FixedOffsetTimeZone.parse("+00:00")
	plain_date_time = Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10)
	instant = Literal::Instant.parse("2025-01-13T10:00:00Z")

	resolution = Literal::PlainDateTimeResolution.new(plain_date_time:, time_zone: zone, instants: [instant])

	assert resolution.resolved?
	refute resolution.ambiguous?
	refute resolution.missing?
	assert_equal [resolution.disambiguate], resolution.candidates
	assert_equal instant, resolution.disambiguate.to_instant
end

test "local date time resolution handles ambiguous and missing instants" do
	zone = Literal::FixedOffsetTimeZone.parse("+00:00")
	plain_date_time = Literal::PlainDateTime.new(year: 2025, month: 1, day: 13, hour: 10)
	earlier = Literal::Instant.parse("2025-01-13T10:00:00Z")
	later = Literal::Instant.parse("2025-01-13T11:00:00Z")

	ambiguous = Literal::PlainDateTimeResolution.new(plain_date_time:, time_zone: zone, instants: [earlier, later])
	assert ambiguous.ambiguous?
	refute ambiguous.resolved?
	refute ambiguous.missing?
	assert_equal earlier, ambiguous.disambiguate(disambiguation: :earlier).to_instant
	assert_equal earlier, ambiguous.disambiguate(disambiguation: :compatible).to_instant
	assert_equal later, ambiguous.disambiguate(disambiguation: :later).to_instant
	assert_raises(ArgumentError) { ambiguous.disambiguate(disambiguation: :reject) }
	assert_raises(ArgumentError) { ambiguous.disambiguate(disambiguation: :invalid) }

	missing = Literal::PlainDateTimeResolution.new(plain_date_time:, time_zone: zone, instants: [], gap: true)
	assert missing.missing?
	refute missing.resolved?
	assert_raises(ArgumentError) { missing.disambiguate }
end
