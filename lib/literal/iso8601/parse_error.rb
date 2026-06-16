# frozen_string_literal: true

class Literal::ISO8601::ParseError < StandardError
	attr_reader :index

	def initialize(message, index)
		super(message)
		@index = index
	end
end
