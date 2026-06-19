# frozen_string_literal: true

class Literal::Result
	def handle(&)
		Literal::ResultHandler.new(self).handle(&)
	end

	def tap_handle(&)
		Literal::ResultHandler.new(self).handle(&)
		self
	end
end
