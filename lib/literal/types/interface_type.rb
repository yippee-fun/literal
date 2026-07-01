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

	def >=(other, context: nil)
		case other
		when Literal::Types::InterfaceType
			@methods.subset?(other.methods)
		when Module
			public_methods = other.public_instance_methods.to_set
			@methods.subset?(public_methods)
		when Literal::Types::ConstraintType
			@methods.all? { |method| other.object_constraints.any? { |type| covers_method?(type, method, context:) } }
		else
			if OwnClassTypeMethodOwners.include?(other.method(:===).owner)
				self === other
			else
				false
			end
		end
	end

	private def covers_method?(type, method, context:)
		case type
		when Literal::Types::InterfaceType
			type.methods.include?(method)
		when Literal::Types::ConstraintType
			type.object_constraints.any? { |constraint| covers_method?(constraint, method, context:) }
		when Module
			type.public_instance_methods.include?(method)
		else
			Literal.subtype?(type, Literal::Types::InterfaceType.new([method]), context:)
		end
	end

	freeze
end
