# frozen_string_literal: true

class Literal::Failure < Literal::Result
	class Generic
		include Literal::Type

		def initialize(type)
			@type = type
			freeze
		end

		attr_reader :type

		def ===(object)
			Literal::Failure === object && @type === object.error!
		end

		def inspect
			"Literal::Failure(#{@type.inspect})"
		end

		freeze
	end

	def initialize(error, success_type:, failure_type:)
		@error = error

		@success_type = success_type
		@failure_type = failure_type

		Literal.check(error, failure_type)

		freeze
	end

	attr_reader :success_type, :failure_type

	def success?
		false
	end

	def failure?
		true
	end

	def value!
		raise Literal::ArgumentError.new("Failure has no value")
	end

	def deconstruct
		[@error]
	end

	def deconstruct_keys(keys)
		if @error.respond_to?(:deconstruct_keys)
			@error.deconstruct_keys(keys)
		else
			{}
		end
	end

	def error!
		@error
	end

	def map(type)
		raise ArgumentError unless block_given?

		Literal::Failure.new(
			@error,
			success_type: type,
			failure_type: @failure_type
		)
	end

	def then
		raise ArgumentError unless block_given?
		self
	end

	def value_or
		raise ArgumentError unless block_given?
		yield(@error)
	end
end
