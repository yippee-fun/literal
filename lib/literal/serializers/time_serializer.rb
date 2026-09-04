# frozen_string_literal: true

require "date"
require "time"

class Literal::TimeSerializer < Literal::Serializer
	Type = _Union(Time, DateTime)
	Precision = _Nilable(_Integer(0..9))

	def self.with(precision: nil, utc: false)
		check_precision(precision)
		options = { precision:, utc: }

		Class.new(self) do
			define_method(:initialize) { |context, **overrides| super(context, **options, **overrides) }

			define_singleton_method(:name) do
				"#{superclass.name}.with(#{options.map { |key, value| "#{key.name}: #{value.inspect}" }.join(', ')})"
			end

			singleton_class.alias_method(:to_s, :name)
			singleton_class.alias_method(:inspect, :name)
		end
	end

	def self.check_precision(precision)
		unless Precision === precision
			raise Literal::ArgumentError, "precision must be nil or an Integer in 0..9, got #{precision.inspect}"
		end
	end

	def initialize(context, precision: nil, utc: false)
		super(context)
		self.class.check_precision(precision)
		@precision = precision
		@utc = utc
	end

	attr_reader :precision
	attr_reader :utc

	def type
		Type
	end

	def handles_type?(type)
		case type
		when Time, DateTime
			true
		else
			super
		end
	end

	def json_type(type)
		"string"
	end

	def json_schema(type, generator: nil)
		case type
		when Time, DateTime
			{ "type" => "string", "format" => "date-time", "const" => serialize_time(type) }
		when Literal::Types::ConstraintType
			constraint_json_schema(type)
		else
			{ "type" => "string", "format" => "date-time" }
		end
	end

	def serialize(value, type:)
		serialize_time(value)
	end

	def deserialize(raw, type:)
		if DateTime === type || Literal.subtype?(type, DateTime)
			DateTime.iso8601(raw)
		else
			Time.iso8601(raw)
		end
	end

	private def constraint_json_schema(type)
		{ "type" => "string", "format" => "date-time" }.tap do |schema|
			type.object_constraints.each do |constraint|
				case constraint
				when Time, DateTime
					schema["const"] = serialize_time(constraint)
				end
			end
		end
	end

	private def serialize_time(value)
		digits = @precision || (fraction_of(value).zero? ? 0 : 9)

		case value
		when Time
			@utc ? value.getutc.iso8601(digits) : value.iso8601(digits)
		when DateTime
			if @utc
				"#{value.new_offset(0).iso8601(digits).delete_suffix('+00:00')}Z"
			else
				value.iso8601(digits)
			end
		end
	end

	private def fraction_of(value)
		case value
		when Time
			value.subsec
		when DateTime
			value.sec_fraction
		end
	end
end
