# frozen_string_literal: true

require "date"
require "time"

class Literal::TimeSerializer < Literal::Serializer
	Type = _Union(Time, DateTime)
	Precision = _Nilable(_Integer(0..9))
	Format = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(?:Z|([+-])(\d{2}):(\d{2}))\z/i

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
		!bound_of(type).nil?
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
		serialize_time(representation(value, type))
	end

	def deserialize(raw, type:)
		date_time = DateTime == bound_of(type)

		# DateTime switches to the Gregorian calendar in 1582, while Time is
		# Gregorian throughout, so each validates dates in its own calendar.
		fields = rfc3339_fields(raw, calendar: date_time ? Date::ITALY : Date::GREGORIAN)

		unless fields
			raise Literal::ArgumentError, "Value #{raw.inspect} is not an RFC 3339 date-time and cannot be deserialized as #{type.inspect}"
		end

		year, month, day, hour, minute, second, offset = fields

		# Built from the fields rather than parsed again, since engines' ISO 8601
		# parsers differ in how much of a long fraction they keep.
		if date_time
			DateTime.new(year, month, day, hour, minute, second, Rational(offset || 0, 86_400))
		else
			Time.new(year, month, day, hour, minute, second, offset || "UTC")
		end
	end

	# Time or DateTime, whichever bounds the type, including constants and
	# unions of them. Both serialize alike, so a type holding both can't be
	# told apart on the way back in, and has no bound.
	private def bound_of(type)
		[Time, DateTime].find do |bound|
			bound === type ||
				within_domain?(type, bound) ||
				(Literal::Types::UnionType === type && type.all?(bound))
		end
	end

	# Ruby's ISO 8601 parsers accept dates without times, times without
	# offsets (read in the machine's timezone) and out-of-range fields they
	# silently roll over, so the format and ranges are checked first.
	# Returns the fields, with the second exact and the offset in seconds, or
	# nil for UTC: Z, or -00:00, which RFC 3339 gives no local offset.
	private def rfc3339_fields(raw, calendar:)
		return unless String === raw && (match = Format.match(raw))

		*date_and_time, fraction, sign, offset_hour, offset_minute = match.captures
		year, month, day, hour, minute, second = date_and_time.map(&:to_i)
		offset_hour, offset_minute = offset_hour.to_i, offset_minute.to_i

		return unless Date.valid_date?(year, month, day, calendar) && hour < 24 && minute < 60 && second < 60 && offset_hour < 24 && offset_minute < 60

		second += Rational(fraction.to_i, 10 ** fraction.length) if fraction
		offset = (offset_hour * 3600) + (offset_minute * 60)

		case sign
		in "+"
			[year, month, day, hour, minute, second, offset]
		in "-" if offset > 0
			[year, month, day, hour, minute, second, -offset]
		in "-" | nil
			[year, month, day, hour, minute, second, nil]
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

	# Fractions are rounded half to even at the written precision, never
	# finer than a nanosecond. Times built from Floats sit a binary hair
	# either side of the decimal they were written as, and rounding recovers
	# it where truncating would turn 30.7 into 30.699999999.
	private def serialize_time(value)
		digits = @precision || 9
		time = rounded(value, digits)
		digits = 0 if @precision.nil? && fraction_of(time).zero?

		serialized = case time
		when Time
			@utc ? time.getutc.iso8601(digits) : time.iso8601(digits)
		when DateTime
			if @utc
				"#{time.new_offset(0).iso8601(digits).delete_suffix('+00:00')}Z"
			else
				time.iso8601(digits)
			end
		end

		# RFC 3339 date-times have four-digit years and offsets under a day.
		unless rfc3339_fields(serialized, calendar: (DateTime === value) ? Date::ITALY : Date::GREGORIAN)
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be written as an RFC 3339 date-time, which needs a year in 0000-9999 and an offset under a day"
		end

		serialized
	end

	private def rounded(value, digits)
		# The whole second counts, so a tie at zero digits rounds to an even second.
		seconds = value.sec + fraction_of(value)
		scale = 10 ** digits
		adjustment = Rational((seconds * scale).round(half: :even), scale) - seconds

		case value
		when Time
			value + adjustment
		when DateTime
			value + (adjustment / 86_400)
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
