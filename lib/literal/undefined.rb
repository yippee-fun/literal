# frozen_string_literal: true

module Literal::Undefined
	def self.inspect
		"Literal::Undefined"
	end

	def self.===(value)
		self == value
	end

	freeze
end
