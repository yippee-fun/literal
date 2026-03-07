# frozen_string_literal: true

require "date"

# Location based instant in time, handles DST automatically.
class Literal::ZonedDateTime < Literal::Data
	include Comparable

	prop :instant, Literal::Instant
	prop :time_zone, Literal::TimeZone
end
