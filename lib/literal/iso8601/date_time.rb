# frozen_string_literal: true

class Literal::ISO8601::DateTime < Literal::ISO8601::Node
	prop :date, Literal::ISO8601::DateNode
	prop :time, Literal::ISO8601::TimeOfDay

	def iso8601
		"#{@date.iso8601}T#{@time.iso8601}"
	end

	def valid?
		@date.valid? && @time.valid?
	end

	alias_method :to_s, :iso8601
end
