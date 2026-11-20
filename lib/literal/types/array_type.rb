# frozen_string_literal: true

# @api private
class Literal::Types::ArrayType
	include Literal::Type

	def initialize(type)
		@type = Literal::Freezing.frozen_member(type)
		@hash = literal_hash(Literal::Types::ArrayType, @type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::ArrayType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::ArrayType === other && Literal.member_eql?(@type, other.type)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Array(#{@type.inspect})"
	end

	def literal_upper_bound
		Array
	end

	def map(&)
		new_type = yield(@type)
		Literal::Types::ArrayType.new(new_type)
	end

	def ===(value)
		Array === value && value.all?(@type)
	end

	def literal_supertype_of?(other, context:)
		case other
		when Literal::Types::ArrayType
			Literal.structural_subtype?(other.type, @type, context:)
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |constraint| Literal.subtype?(constraint, self, context:) }
		else
			false
		end
	end

	def record_literal_type_errors(context)
		unless Array === context.actual
			return
		end

		context.actual.each_with_index do |item, index|
			unless @type === item
				context.add_child(label: "[#{index}]", expected: @type, actual: item)
			end
		end
	end

	freeze
end
