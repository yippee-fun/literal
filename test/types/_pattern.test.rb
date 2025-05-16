# frozen_string_literal: true

include Literal::Types

test "with named params" do
	pattern = _Pattern(/\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\z/) do |year:, month:, day:|
		year.to_i >= 2000 && month.to_i.between?(1, 12) && day.to_i.between?(1, 31)
	end

	assert pattern === "2023-04-15"
	assert pattern === "2050-01-01"

	refute pattern === "1999-12-31"
	refute pattern === "2023-13-01"
	refute pattern === "2023-01-32"
	refute pattern === "abc-12-31"
end

test "with positional params" do
	pattern = _Pattern(/\A(\d+)-(\d+)-(\d+)\z/) do |year, month, day|
		year.to_i >= 2000 && month.to_i.between?(1, 12) && day.to_i.between?(1, 31)
	end

	assert pattern === "2023-04-15"
	assert pattern === "2050-01-01"

	refute pattern === "1999-12-31"
	refute pattern === "2023-13-01"
	refute pattern === "2023-01-32"
	refute pattern === "abc-12-31"
end
