# frozen_string_literal: true

# @api private
class Literal::Types::JSONDataType
	Instance = new.freeze

	include Literal::Type

	COMPATIBLE_TYPES = Set[
		Integer,
		Float,
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
		when String, Integer, Float, true, false, nil
			true
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
		when String, Integer, Float, true, false, nil
			# nothing to do
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

	def >=(other)
		return true if COMPATIBLE_TYPES.include?(other)

		case other
		when Literal::Types::ArrayType
			Literal.subtype?(other.type, self)
		when Literal::Types::HashType
			(Literal.subtype?(other.key_type, self) && Literal.subtype?(other.value_type, self))
		when Literal::Types::ConstraintType
			other.object_constraints.any? { |type| self >= type }
		else
			false
		end
	end

	freeze
end
