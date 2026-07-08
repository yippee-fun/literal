# frozen_string_literal: true

class Literal::Brand
	include Literal::Types

	def initialize(...)
		@type = _Constraint(...)
		raise Literal::ArgumentError.new("Cannot create a brand for an immediate value type.") if _Kind(Literal::Immediate) === @type

		@objects = ObjectSpace::WeakMap.new
	end

	def new(object)
		if String === object
			frozen = object.frozen?
			object = object.dup
			object.freeze if frozen
		end

		Literal.check(object, @type)
		raise Literal::ArgumentError.new("Cannot brand immediate values.") if object in Literal::Immediate

		@objects[object] = object
		object
	end

	alias_method :[], :new

	def ===(value)
		@objects.key?(value)
	end
end
