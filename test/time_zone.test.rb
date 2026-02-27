# frozen_string_literal: true

test "time zone module coercion and parser" do
	named = Literal::TimeZone.coerce("Europe/London")
	fixed = Literal::TimeZone.parse("+01:00")

	assert Literal::TimeZone === named
	assert Literal::TimeZone === fixed
	refute Literal::TimeZone === "UTC"
	assert_equal fixed, Literal::TimeZone.coerce(fixed)
	assert_equal fixed, ["+01:00"].map(&Literal::TimeZone).first
	assert_equal "UTC", Literal::TimeZone.utc.identifier
	assert Literal::NamedTimeZone === Literal::TimeZone.country_zones.first
	assert Literal::NamedTimeZone === Literal::TimeZone.all_zones.first
	assert_raises(ArgumentError) { Literal::TimeZone.coerce(123) }
end
