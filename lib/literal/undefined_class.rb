# frozen_string_literal: true

# The class of the `Literal::Undefined` sentinel. The sentinel is a plain
# object rather than a module so that it sits outside the object model —
# `Module === Literal::Undefined` is false — and only satisfies types that
# would accept any truthy object.
class Literal::UndefinedClass
	def inspect
		"Literal::Undefined"
	end

	alias_method :to_s, :inspect

	# Every instance is the one sentinel, so a copy conjured through allocate
	# or Marshal still compares equal and hashes together.
	def ==(other)
		Literal::UndefinedClass === other
	end

	alias_method :eql?, :==

	def hash
		Literal::UndefinedClass.hash
	end

	def dup
		self
	end

	def clone(freeze: nil)
		self
	end

	def present?
		false
	end

	def blank?
		true
	end

	# Marshal restores the sentinel itself rather than a copy. A module
	# round-tripped by name for free; an object has to say so.
	def _dump(_level)
		""
	end

	def self._load(_data)
		Literal::Undefined
	end

	Instance = new.freeze
end
