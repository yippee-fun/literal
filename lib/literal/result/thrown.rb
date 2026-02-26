# frozen_string_literal: true

class Literal::Result::Thrown
	def initialize(result)
		@result = result
		freeze
	end

	attr_reader :result
end
