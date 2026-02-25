# frozen_string_literal: true

class Literal::Serializer
	extend Literal::Types
	include Literal::Types

	def initialize(context)
		@context = context
	end
end
