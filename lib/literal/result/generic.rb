# frozen_string_literal: true

class Literal::Result::Generic
	include Literal::Type

	# takes a type (t), if it is already a result type, returns it
	# otherwise, returns Literal::Result(t, _Never) — a result object for `t` that can never fail
	def self.coerce(t)
		case t
		when Literal::Result::Generic
			t
		else
			Literal::Result(t, Literal::Types::_Never)
		end
	end

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

	def >=(other, context: nil)
		case other
		when Literal::Result::Generic
			Literal.subtype?(other.success_type, @success_type, context:) && Literal.subtype?(other.failure_type, @failure_type, context:)
		else
			false
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
