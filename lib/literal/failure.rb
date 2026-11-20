# frozen_string_literal: true

class Literal::Failure < Literal::Result
	class Generic
		include Literal::Type

		def initialize(type)
			@type = Literal::Freezing.frozen_member(type)
			freeze
		end

		attr_reader :type

		def ===(object)
			Literal::Failure === object && !!(@type === object.error!)
		end

		def ==(other)
			Generic === other && @type == other.type
		end

		def eql?(other)
			Generic === other && Literal.member_eql?(@type, other.type)
		end

		def hash
			literal_hash(Generic, @type)
		end

		def literal_supertype_of?(other, context:)
			case other
			when Generic
				Literal.structural_subtype?(other.type, @type, context:)
			else
				false
			end
		end

		def literal_upper_bound
			Literal::Failure
		end

		def inspect
			"Literal::Failure(#{@type.inspect})"
		end

		def name
			Literal.const_name(self)
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

	def ==(other)
		return false unless Literal::Failure === other

		error = other.error!
		Literal::EQUAL.bind_call(@error, error) || @error == error
	end

	def eql?(other)
		Literal::Failure === other && Literal.payload_eql?(@error, other.error!)
	end

	def hash
		[Literal::Failure, Literal.payload_hash(@error)].hash
	end

	def map(type)
		raise Literal::ArgumentError unless block_given?

		Literal::Failure.new(
			@error,
			success_type: type,
			failure_type: @failure_type
		)
	end

	def also
		raise Literal::ArgumentError unless block_given?
		self
	end

	def and_then
		raise Literal::ArgumentError unless block_given?
		self
	end

	def value_or
		raise Literal::ArgumentError unless block_given?
		yield(@error)
	end
end
