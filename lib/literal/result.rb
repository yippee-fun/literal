# frozen_string_literal: true

class Literal::Result
	class Generic
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

	def handle(&)
		Literal::ResultHandler.new(self).handle(&)
	end
end
