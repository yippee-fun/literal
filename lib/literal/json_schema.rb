# frozen_string_literal: true

module Literal::JSONSchema
	String = StringType.new
	Number = NumberType.new
	Integer = IntegerType.new

	def self.String(...)
		StringType.new(...)
	end

	def self.Number(...)
		NumberType.new(...)
	end

	def self.Integer(...)
		IntegerType.new(...)
	end
end
