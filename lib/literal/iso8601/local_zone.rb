# frozen_string_literal: true

class Literal::ISO8601::LocalZone < Literal::ISO8601::Node
	def iso8601
		""
	end

	def valid?
		true
	end

	alias_method :to_s, :iso8601
end
