# frozen_string_literal: true

# @api private
class Literal::Types::InterfaceType
	include Literal::Type

	# List of `===` method owners where the comparison will only match for objects with the same class
	OwnClassTypeMethodOwners = Set[String, Integer, Kernel, Float, NilClass, TrueClass, FalseClass].freeze

	def initialize(methods)
		raise Literal::ArgumentError.new("_Interface type must have at least one method.") if methods.size < 1
		@methods = methods.to_set.freeze
		freeze
	end

	attr_reader :methods

	def inspect
		"_Interface(#{@methods.map(&:inspect).join(', ')})"
	end

	def ===(value)
		@methods.each do |method|
			return false unless value.respond_to?(method)
		end

		true
	end

	def >=(other)
		case other
		when Literal::Types::InterfaceType
			@methods.subset?(other.methods)
		when Module
			public_methods = other.public_instance_methods.to_set
			@methods.subset?(public_methods)
		when Literal::Types::IntersectionType
			other.types.any? { |type| Literal.subtype?(type, self) }
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |type| Literal.subtype?(type, self) }
		else
			if OwnClassTypeMethodOwners.include?(other.method(:===).owner)
				self === other
			else
				false
			end
		end
	end

	freeze
end
