# frozen_string_literal: true

class Literal::PlainDateTimeRange < Literal::Data
	prop :from, Literal::PlainDateTime
	prop :to, Literal::PlainDateTime

	def after_initialize
		if @from > @to
			raise ArgumentError, "from must be less than to"
		end
	end
end
