# frozen_string_literal: true

class Literal::Function
	class Generic
		include Literal::Type

		def initialize(sig)
			case sig
			when Hash
				raise unless sig.length == 1
				@input_type, @result_type = sig.first
			else
				@input_type = sig
				@result_type = _Void
			end
		end

		def ===(other)
			case other
			when Literal::Function
				Literal.subtype?(other.input_type, @input_type) && Literal.subtype?(other.result_type, @result_type)
			else
				false
			end
		end

		def >=(other_type)
			case other_type
			when Literal::Function::Generic
				Literal.subtype?(other.input_type, @input_type) && Literal.subtype?(other.result_type, @result_type)
			else
				false
			end
		end

		def new(&)
			Literal::Function.new(@input_type, @result_type, &)
		end
	end

	include Literal::Types

	attr_reader :input_type, :input_result_type, :result_type

	def initialize(input_type, result_type, &block)
		@input_type = input_type
		@input_result_type = Literal::Result(@input_type, _Any)

		@result_type = Literal::Result::Generic.coerce(result_type)

		@block = block
	end

	def to_proc
		me = self
		proc { |input| me.call(input) }
	end

	def call(input, &)
		Literal.check(input, @input_type)

		@result_type.try do |emitter|
			@block.call(emitter, input)
		end.handle(&)
	end

	def run(input_result, &)
		Literal.check(input_result, @input_result_type)

		input_result.and_then do |value|
			@result_type.try do |emitter|
				emitter.instance_exec(value, &@block)
			end
		end.handle(&)
	end
end
