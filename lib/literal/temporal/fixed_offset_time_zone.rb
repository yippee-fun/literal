# frozen_string_literal: true

class Literal::FixedOffsetTimeZone < Literal::TimeZone
	prop :offset_in_seconds, Integer
end
