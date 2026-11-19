# frozen_string_literal: true

class Literal::Properties::DataSchema < Literal::Properties::Schema
	def generate_after_initializer(buffer = +"")
		super
		buffer << "  ::Literal::FREEZE.bind_call(self)\n"
	end
end
