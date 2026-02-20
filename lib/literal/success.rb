# frozen_string_literal: true

class Literal::Success < Literal::Result
	class Generic
		include Literal::Type

		def initialize(type)
			@type = type
			freeze
		end

		attr_reader :type

		def ===(object)
			Literal::Success === object && @type === object.value!
		end

		def inspect
			"Literal::Success(#{@type.inspect})"
		end

		freeze
	end

	def initialize(value, success_type:, failure_type:)
		@value = value

		@success_type = success_type
		@failure_type = failure_type

		Literal.check(@value, success_type)

		freeze
	end

	attr_reader :success_type, :failure_type

	def success?
		true
	end

	def failure?
		false
	end

	def value!
		@value
	end

	def deconstruct
		[@value]
	end

	def deconstruct_keys(keys)
		if @value.respond_to?(:deconstruct_keys)
			@value.deconstruct_keys(keys)
		else
			{}
		end
	end

	def error!
		raise Literal::ArgumentError.new("Success has no error")
	end

	def map(type)
		raise ArgumentError unless block_given?
		result = yield(@value)

		Literal::Success.new(
			result,
			success_type: type,
			failure_type: @failure_type
		)
	end

	def then
		raise ArgumentError unless block_given?
		result = yield(@value)

		case result
		when Literal::Failure
			Literal::Failure.new(
				result.error!,
				success_type: result.success_type,
				failure_type: Literal::Types::_Union(@failure_type, result.failure_type)
			)
		when Literal::Success
			Literal::Success.new(
				result.value!,
				success_type: result.success_type,
				failure_type: Literal::Types::_Union(@failure_type, result.failure_type)
			)
		else
			raise Literal::ArgumentError.new("Expected block to return a Literal::Result, got #{result.class.inspect}")
		end
	end

	def value_or
		raise ArgumentError unless block_given?
		@value
	end
end
