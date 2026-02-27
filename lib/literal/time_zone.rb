# frozen_string_literal: true

module Literal::TimeZone
	def self.===(value)
		case value
		when Literal::FixedOffsetTimeZone
			true
		else
			"Literal::NamedTimeZone" == value.class.name
		end
	end

	def self.coerce(value)
		case value
		when Literal::FixedOffsetTimeZone
			value
		when String
			begin
				Literal::FixedOffsetTimeZone.parse(value)
			rescue ArgumentError
				Literal::NamedTimeZone.new(value)
			end
		else
			if self === value
				value
			else
				raise ArgumentError
			end
		end
	end

	def self.parse(value)
		coerce(value)
	end

	def self.to_proc
		-> (value) { coerce(value) }
	end

	def self.utc
		Literal::NamedTimeZone.utc
	end

	def self.country_zones
		Literal::NamedTimeZone.country_zones
	end

	def self.all_zones
		Literal::NamedTimeZone.all_zones
	end
end
