# frozen_string_literal: true

class Literal::Result::Generic
	include Literal::Type
	include Literal::Types::Distributed

	def initialize(success_type, failure_type)
		@success_type = Literal::Freezing.frozen_member(success_type)
		@failure_type = Literal::Freezing.frozen_member(failure_type)

		freeze
	end

	attr_reader :success_type, :failure_type

	def ===(object)
		case object
		when Literal::Success
			!!(@success_type === object.value!)
		when Literal::Failure
			!!(@failure_type === object.error!)
		else
			false
		end
	end

	def ==(other)
		Literal::Result::Generic === other && @success_type == other.success_type && @failure_type == other.failure_type
	end

	def eql?(other)
		Literal::Result::Generic === other && Literal.member_eql?(@success_type, other.success_type) && Literal.member_eql?(@failure_type, other.failure_type)
	end

	def hash
		literal_hash(Literal::Result::Generic, @success_type, @failure_type)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::Distributed, Literal::Types::DeferredType
			Literal.subtype?(other, self, context:)
		when Literal::Success::Generic
			Literal.structural_subtype?(other.type, @success_type, context:)
		when Literal::Failure::Generic
			Literal.structural_subtype?(other.type, @failure_type, context:)
		else
			false
		end
	end

	def inspect
		"Literal::Result(#{@success_type.inspect}, #{@failure_type.inspect})"
	end

	def name
		Literal.const_name(self)
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
