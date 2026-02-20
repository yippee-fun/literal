# frozen_string_literal: true

class Literal::ResultHandler
	def initialize(result)
		@result = result
		@success_cases = []
		@failure_cases = []
	end

	def handle
		return @result unless block_given?

		yield(self)

		unless Literal.subtype?(@result.success_type, covered_type(@success_cases))
			raise Literal::ArgumentError.new("No success handler covers #{@result.success_type.inspect}")
		end

		unless Literal.subtype?(@result.failure_type, covered_type(@failure_cases))
			raise Literal::ArgumentError.new("No failure handler covers #{@result.failure_type.inspect}")
		end

		case @result
		when Literal::Success
			@success_cases.each do |type, block|
				if type === @result.value!
					return block&.call(@result.value!)
				end
			end
		when Literal::Failure
			@failure_cases.each do |type, block|
				if type === @result.error!
					return block&.call(@result.error!)
				end
			end
		end

		raise Literal::ArgumentError.new("Unhandled result type: #{@result.class}")
	end

	def success(type = Literal::Types::_Any?, &block)
		@success_cases << [type, block]
	end

	def failure(type = Literal::Types::_Any?, &block)
		@failure_cases << [type, block]
	end

	private def covered_type(cases)
		return Literal::Types::NeverType::Instance if cases.empty?

		Literal::Types::_Union(*cases.map(&:first))
	end
end
