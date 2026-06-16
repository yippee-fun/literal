# frozen_string_literal: true

test "iso8601 offset zone formatting and sign validation" do
	positive = Literal::ISO8601::OffsetZone.new(sign: 1, hours: 1, minutes: 30)
	negative = Literal::ISO8601::OffsetZone.new(sign: -1, hours: 5, minutes: 0)
	invalid = Literal::ISO8601::OffsetZone.new(sign: 1, hours: 24, minutes: 0)

	assert_equal positive.iso8601, "+01:30"
	assert_equal negative.iso8601, "-05:00"
	assert positive.valid?
	assert negative.valid?
	refute invalid.valid?
	assert_raises(Literal::TypeError) { Literal::ISO8601::OffsetZone.new(sign: 0, hours: 1, minutes: 30) }
end
