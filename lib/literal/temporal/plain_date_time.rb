# frozen_string_literal: true

class Literal::PlainDateTime < Literal::Data
	prop :year, Integer
	prop :month, Literal::Temporal::MonthInt
	prop :day, Literal::Temporal::DayInt
	prop :ns, Integer
end
