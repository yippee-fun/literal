# frozen_string_literal: true

class Literal::Result
	def handle(&)
		Literal::ResultHandler.new(self).handle(&)
	end
end
