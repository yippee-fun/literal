# frozen_string_literal: true

class Literal::Rails::FlagsType < ActiveModel::Type::Value
	def initialize(flags_class)
		@flags_class = flags_class
		super()
	end

	def cast(value)
		case value
		when @flags_class
			value
		when Integer
			@flags_class.from_int(value)
		else
			deserialize(value)
		end
	end

	def serialize(value)
		case value
		when nil
			nil
		when @flags_class
			value.to_bit_string
		else
			raise Literal::ArgumentError.new(
				"Invalid value: #{value.inspect}. Expected an #{@flags_class.inspect}.",
			)
		end
	end

	# Only bit strings, since that's what serialize writes: an integer column
	# would hand "00000010" back as 10.
	def deserialize(value)
		case value
		when nil
			nil
		else
			@flags_class.from_bit_string(value)
		end
	end
end
