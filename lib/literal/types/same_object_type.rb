# frozen_string_literal: true

# @api private
class Literal::Types::SameObjectType
	include Literal::Type

	EQUAL_METHOD = Literal.method_handle(BasicObject, :equal?)

	def initialize(object)
		@object = object
		@hash = [Literal::Types::SameObjectType, Literal::OBJECT_ID.bind_call(object)].hash
		freeze
	end

	attr_reader :object, :hash

	def ==(other)
		Literal::Types::SameObjectType === other && EQUAL_METHOD.bind_call(@object, other.object)
	end

	alias_method :eql?, :==

	def inspect
		"_SameObject(#{@object.inspect})"
	end

	def ===(value)
		EQUAL_METHOD.bind_call(@object, value)
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::SameObjectType
			EQUAL_METHOD.bind_call(@object, other.object)
		else
			false
		end
	end

	# The only value is @object itself, so this is a subtype of any module or
	# range that admits it — including Integer for _SameObject(10), where bare
	# 10 is not. Literal types can admit it for state that later changes.
	def literal_subtype_of?(other, context:)
		case other
		when Literal::Type
			false
		when Module, Range
			!!(other === @object)
		else
			false
		end
	end

	freeze
end
