# frozen_string_literal: true

class Literal::Types::KindType
	include Literal::Type

	def initialize(type)
		@type = type
		@hash = literal_hash(Literal::Types::KindType, type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::KindType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::KindType === other && @type.eql?(other.type)
	end

	def inspect
		"_Kind(#{@type.inspect})"
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def ===(object)
		Literal.subtype?(object, @type)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::KindType, Literal::Types::ClassType, Literal::Types::DescendantType
			Literal.subtype?(other.type, @type, context:)
		else
			false
		end
	end

	freeze
end
