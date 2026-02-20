# frozen_string_literal: true

# @api private
class Literal::Types::IntersectionType
	include Literal::Type

	def initialize(types)
		raise Literal::ArgumentError.new("_Intersection type must have at least one type.") if types.size < 1

		@types = types
		freeze
	end

	attr_reader :types

	def inspect = "_Intersection(#{@types.map(&:inspect).join(', ')})"

	def ===(value)
		@types.all? { |type| type === value }
	end

	def nil?
		@types.all?(&:nil?)
	end

	def record_literal_type_errors(context)
		@types.each do |type|
			next if type === context.actual

			context.add_child(label: inspect, expected: type, actual: context.actual)
		end
	end

	def >=(other)
		case other
		when Literal::Types::IntersectionType
			@types.all? do |type|
				other.types.any? do |other_type|
					Literal.subtype?(other_type, type)
				end
			end
		when Literal::Types::ConstraintType
			@types.all? do |type|
				other.object_constraints.any? do |object_constraint|
					Literal.subtype?(object_constraint, type)
				end
			end
		when Literal::Types::FrozenType
			@types.all? { |type| Literal.subtype?(other.type, type) }
		else
			false
		end
	end

	def <=(other)
		case other
		when Module
			@types.any? { |type| Literal.subtype?(type, other) }
		end
	end

	freeze
end
