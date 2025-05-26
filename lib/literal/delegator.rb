# frozen_string_literal: true

class Literal::Delegator < SimpleDelegator
	def self.to_proc
		-> (value) { new(value) }
	end

	def self.[](value)
		new(value)
	end

	def initialize(value)
		Literal.check(value, __type__)
		super
		freeze
	end

	def ===(other)
		self.class === other && __getobj__ == other.__getobj__
	end

	alias_method :==, :===

	freeze
end
