# frozen_string_literal: true

require "time"

# Models a point in time irrespective of time zone.
class Literal::Instant < Literal::Data
	include Comparable

	# The number of nanoseconds since the Unix Epoch (January 1, 1970, 00:00:00 UTC).
	prop :unix_timestamp_in_nanoseconds, Integer
end
