# frozen_string_literal: true

class Literal::Rails::FlagsType < ActiveModel::Type::Value
	BLANK = /\A[[:space:]]*\z/
	# SQLite hands integer column defaults over as strings.
	DECIMAL = /\A\d+\z/

	private_constant :BLANK, :DECIMAL

	def initialize(flags_class, format: :bit_string)
		case format
		in :bit_string | :integer
			nil
		else
			raise Literal::ArgumentError.new(
				"Invalid format: #{format.inspect}. Expected :bit_string or :integer.",
			)
		end

		@flags_class = flags_class
		@format = format
		super()
	end

	attr_reader :flags_class, :format

	def ==(other)
		super && @flags_class == other.flags_class && @format == other.format
	end

	alias_method :eql?, :==

	def hash
		[super, @flags_class, @format].hash
	end

	def cast(value)
		case value
		when nil, @flags_class
			value
		when Integer
			@flags_class.from_int(value)
		when String
			BLANK.match?(value) ? nil : @flags_class.from_bit_string(value)
		else
			@flags_class.from_bit_string(value)
		end
	end

	def serialize(value)
		case value
		when nil
			nil
		when @flags_class
			case @format
			in :bit_string then value.to_bit_string
			in :integer then value.to_i
			end
		else
			raise Literal::ArgumentError.new(
				"Invalid value: #{value.inspect}. Expected an #{@flags_class.inspect}.",
			)
		end
	end

	def deserialize(value)
		return nil if nil == value

		case @format
		in :bit_string then @flags_class.from_bit_string(value)
		in :integer then @flags_class.from_int((DECIMAL === value) ? value.to_i : value)
		end
	end
end
