# frozen_string_literal: true

test "duration arithmetic and comparison" do
	duration = Literal::Duration.new(nanoseconds: 10_500_000_000)
	other = Literal::Duration.new(nanoseconds: 5_250_000_000)

	assert_equal 10, duration.to_i
	assert_equal 10.5, duration.to_f
	assert_raises(Literal::ArgumentError) { duration + 2 }
	assert_raises(Literal::ArgumentError) { duration - 2 }
	assert_equal Literal::Duration.new(nanoseconds: 15_750_000_000), duration + other
	assert_equal Literal::Duration.new(nanoseconds: 5_250_000_000), duration - other
	assert_equal Literal::Duration.new(nanoseconds: -10_500_000_000), -duration
	assert_equal(-1, other <=> duration)
	assert_equal(0, duration <=> Literal::Duration.new(nanoseconds: 10_500_000_000))
	assert_equal(1, duration <=> other)
	assert duration < Literal::Duration.new(nanoseconds: 11_000_000_000)
	assert_equal(-1, other <=> duration)
end
