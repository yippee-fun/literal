# frozen_string_literal: true

class TimeTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		current_time = Time.now

		assert _Time (_Interface(:to_time)) === current_time
		assert _Time(current_time) === current_time
		assert _Time(current_time..) === current_time + 60

		refute _Time(_Interface(:non_existing_method)) === current_time
		refute _Time(current_time..) === current_time - 60

		unless RUBY_ENGINE == "jruby"
			assert _Time(zone: "UTC") === Time.new(2025, 1, 13, 20, 0, 0, "UTC")
		end

		fifteen_mins_ago = proc { |t| ((Time.now - (60 * 15))..(Time.now)) === t }
		assert _Time(fifteen_mins_ago) === Time.now - (60 * 10)
		refute _Time(fifteen_mins_ago) === Time.now - (60 * 20)
		occurs_on_monday = proc(&:monday?)
		assert _Time(occurs_on_monday) === Time.new(2025, 1, 13)
		refute _Time(occurs_on_monday) === Time.new(2025, 1, 14)

		refute _Time(Time.new(2025, 1, 13, 20, 0, 0, "UTC")) === "2025-01-13 20:00:00 UTC"
		refute _Time(Time.new(2025, 1, 13, 20, 0, 0, "UTC")) === nil
	end
end
