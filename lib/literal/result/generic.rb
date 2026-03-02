# frozen_string_literal: true

class Literal::Result::Generic
	include Literal::Type

	def initialize(success_type, failure_type)
		@success_type = success_type
		@failure_type = failure_type

		freeze
	end

	attr_reader :success_type, :failure_type

	def ===(object)
		case object
		when Literal::Success
			@success_type === object.value!
		when Literal::Failure
			@failure_type === object.error!
		end
	end

	def try
		raise ArgumentError unless block_given?

		caught = catch do |ball|
			emitter = Literal::Result::Emitter.new(type: self, ball:)
			yield(emitter)
		end

		case caught
		when Literal::Result::Thrown
			Literal.check(caught.result, self)
			caught.result
		else
			raise Literal::ArgumentError.new("Expected block to throw a success or failure result")
		end
	end

	def success(value)
		Literal::Success.new(
			value,
			success_type: @success_type,
			failure_type: @failure_type
		)
	end

	def failure(error)
		Literal::Failure.new(
			error,
			success_type: @success_type,
			failure_type: @failure_type
		)
	end

	freeze
end
