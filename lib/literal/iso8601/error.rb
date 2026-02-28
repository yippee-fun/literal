# frozen_string_literal: true

class Literal::ISO8601::Error < Literal::Data
	prop :index, Integer
	prop :message, String
	prop :input, String

	def error?
		true
	end

	def to_s
		"Invalid ISO8601 value at byte #{@index}: #{@message} (#{@input.inspect})"
	end
end
