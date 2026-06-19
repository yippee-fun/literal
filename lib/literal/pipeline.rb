# frozen_string_literal: true

class Literal::Pipeline
	Undefined = Object.new
	include Literal::Types
	extend Literal::Types

	Step = _Interface(:input_type, :result_type, :run)

	attr_reader :result_type, :input_type

	def initialize(sig, &block)
		case sig
		when Hash
			raise unless sig.length == 1
			input_type, final_result_type = sig.first
		else
			input_type = sig
			final_result_type = Undefined
		end

		@input_type = input_type
		@input_result_type = Literal::Result(input_type, _Never)
		@result_type = Literal::Result(input_type, _Never)

		@steps = []

		if block_given?
			if block.arity == 0
				instance_exec(&block)
			else
				yield(self)
			end
		end

		@steps.freeze
		freeze

		if (Undefined != final_result_type) && !Literal.subtype?(@result_type, Literal::Result::Generic.coerce(final_result_type))
			raise
		end
	end

	def Result(...)
		Literal::Result(...)
	end

	def add_step(step)
		Literal.check(step, Step)
		raise unless Literal.subtype?(@result_type.success_type, step.input_type)
		@steps << step
		@result_type = step.result_type
	end

	def step(new_result_type, &)
		new_result_type = Literal::Result::Generic.coerce(new_result_type)

		@steps << Literal::Function(@result_type.success_type => new_result_type).new(&)
		@result_type = new_result_type
	end

	def map(new_success_type)
		step(Literal::Result(new_success_type, _Never)) do |value|
			success(yield(value))
		end
	end

	def call(input, &)
		Literal.check(input, @input_type)

		result = @input_result_type.success(input)

		@steps.each do |step|
			result = step.run(result)
		end

		result.handle(&)
	end

	def run(input_result, &)
		Literal.check(input_result, @input_result_type)

		result = input_result

		@steps.each do |step|
			result = step.run(result)
		end

		result.handle(&)
	end

	def success_type
		@result_type.success_type
	end

	def failure_type
		@result_type.failure_type
	end
end
