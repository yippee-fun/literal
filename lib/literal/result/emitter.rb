# frozen_string_literal: true

class Literal::Result::Emitter
	def initialize(type:, ball:)
		@type = type
		@ball = ball
		freeze
	end

	def success(value)
		throw(@ball, Literal::Result::Thrown.new(@type.success(value)))
	end

	def failure(error)
		throw(@ball, Literal::Result::Thrown.new(@type.failure(error)))
	end
end
