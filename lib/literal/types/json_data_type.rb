# frozen_string_literal: true

# @api private
class Literal::Types::JSONDataType
	Instance = new.freeze

	include Literal::Type

	COMPATIBLE_TYPES = Set[
		Integer,
		String,
		true,
		false,
		nil,
		Literal::Types::BooleanType::Instance,
		Instance
	].freeze

	def inspect = "_JSONData"

	def ===(value)
		case value
		when String, Integer, true, false, nil
			true
		when Float
			value.finite?
		when Hash
			value.each do |k, v|
				return false unless String === k && self === v
			end
		when Array
			value.all?(self)
		else
			false
		end
	end

	def record_literal_type_errors(context)
		case value = context.actual
		when String, Integer, true, false, nil
			# nothing to do
		when Float
			context.add_child(label: inspect, expected: "finite Float", actual: value) unless value.finite?
		when Hash
			value.each do |k, v|
				context.add_child(label: "[]", expected: String, actual: k) unless String === k
				context.add_child(label: "[#{k.inspect}]", expected: self, actual: v) unless self === v
			end
		when Array
			value.each_with_index do |item, index|
				context.add_child(label: "[#{index}]", expected: self, actual: item) unless self === item
			end
		end
	end

	def >=(other, context: nil)
		return true if COMPATIBLE_TYPES.include?(other)

		case other
		when Literal::Types::ArrayType
			Literal.subtype?(other.type, self, context:)
		when Literal::Types::HashType
			(Literal.subtype?(other.key_type, self, context:) && Literal.subtype?(other.value_type, self, context:))
		when Literal::Types::ConstraintType
			Literal.subtype?(other, Literal::Types._Float(finite?: true), context:) ||
				other.object_constraints.any? { |type| self.>=(type, context:) }
		else
			false
		end
	end

	freeze
end
