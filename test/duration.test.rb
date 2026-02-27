# frozen_string_literal: true

test "duration arithmetic and comparison" do
	duration = Literal::Duration.new(seconds: 10, subseconds: Rational(1, 2))
	other = Literal::Duration.new(seconds: 5, subseconds: Rational(1, 4))

	assert_equal 10, duration.to_i
	assert_equal 10.5, duration.to_f
	assert_equal Literal::Duration.new(seconds: 12, subseconds: Rational(1, 2)), duration + 2
	assert_equal Literal::Duration.new(seconds: 8, subseconds: Rational(1, 2)), duration - 2
	assert_equal Literal::Duration.new(seconds: 15, subseconds: Rational(3, 4)), duration + other
	assert_equal Literal::Duration.new(seconds: 5, subseconds: Rational(1, 4)), duration - other
	assert_equal Literal::Duration.new(seconds: -10, subseconds: Rational(-1, 2)), -duration
	assert_equal(-1, other <=> duration)
	assert_equal(0, duration <=> Literal::Duration.new(seconds: 10, subseconds: Rational(1, 2)))
	assert_equal(1, duration <=> other)
	assert duration < Literal::Duration.new(seconds: 11)
	assert_equal(-1, Literal::Duration.compare(other, duration))
	assert duration.equals(duration.with)
end
