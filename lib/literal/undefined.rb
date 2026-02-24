# frozen_string_literal: true

module Literal::Undefined
	def self.inspect
		"Literal::Undefined"
	end

	def self.===(value)
		self == value
	end

	def self.present?
		false
	end

	def self.blank?
		true
	end

	freeze
end
