# frozen_string_literal: true

require "date"
require "ipaddr"
require "time"
require "uri"

class Literal::JSONSchema::StringType < Literal::Data
	include Literal::Type

	Formats = ::Set[
		"date-time",
		"date",
		"time",
		"duration",
		"email",
		"idn-email",
		"hostname",
		"idn-hostname",
		"ipv4",
		"ipv6",
		"uri",
		"uri-reference",
		"iri",
		"iri-reference",
		"uuid",
		"uri-template",
		"json-pointer",
		"relative-json-pointer",
		"regex",
	].freeze

	prop :format, _Nilable(_Union(*Formats))
	prop :pattern, _Nilable(::Regexp)
	prop :min_length, _Nilable(_Integer(0..))
	prop :max_length, _Nilable(_Integer(0..))

	def after_initialize
		if @pattern && !defined?(JsRegex)
			raise ::ArgumentError, "You need to install and require the js_regex gem to use Regexp patterns."
		end
	end

	def inspect
		"Literal::JSONSchema::String(#{json_schema.inspect})"
	end

	def ===(value)
		return false unless ::String === value
		return false if !min_length.nil? && value.length < min_length
		return false if !max_length.nil? && value.length > max_length
		return false if pattern && !pattern.match?(value)
		return false if format && !format_matches?(value)

		true
	end

	def <=(other, context: nil)
		Literal.subtype?(::String, other, context:)
	end

	def json_schema
		{ "type" => "string" }.tap do |schema|
			schema["format"] = format if format
			schema["pattern"] = JsRegex.new(pattern, target: "ES2018").source if pattern
			schema["minLength"] = min_length unless min_length.nil?
			schema["maxLength"] = max_length unless max_length.nil?
		end
	end

	private def format_matches?(value)
		case format
		when "date-time"
			parse_time(value)
		when "date"
			/\A\d{4}-\d{2}-\d{2}\z/.match?(value) && parse_date(value)
		when "time"
			parse_time("1970-01-01T#{value}")
		when "duration"
			/\AP(?!\z)(?:\d+Y)?(?:\d+M)?(?:\d+D)?(?:T(?:\d+H)?(?:\d+M)?(?:\d+(?:\.\d+)?S)?)?\z/.match?(value)
		when "email", "idn-email"
			/\A[^@\s]+@[^@\s]+\z/.match?(value)
		when "hostname", "idn-hostname"
			hostname?(value)
		when "ipv4"
			ip_address(value)&.ipv4?
		when "ipv6"
			ip_address(value)&.ipv6?
		when "uri", "iri"
			uri?(value, absolute: true)
		when "uri-reference", "iri-reference"
			uri?(value, absolute: false)
		when "uuid"
			/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(value)
		when "uri-template"
			uri_template?(value)
		when "json-pointer"
			value.empty? || value.start_with?("/")
		when "relative-json-pointer"
			%r{\A(?:0|[1-9]\d*)(?:#|(?:/.*)?)\z}.match?(value)
		when "regex"
			regex?(value)
		end
	end

	private def parse_time(value)
		::Time.iso8601(value)
		true
	rescue ::ArgumentError
		false
	end

	private def parse_date(value)
		::Date.iso8601(value)
		true
	rescue ::ArgumentError
		false
	end

	private def ip_address(value)
		::IPAddr.new(value)
	rescue ::IPAddr::InvalidAddressError
		nil
	end

	private def uri?(value, absolute:)
		uri = ::URI.parse(value)
		!absolute || !!uri.scheme
	rescue ::URI::InvalidURIError
		false
	end

	private def hostname?(value)
		value.length <= 253 &&
			value.split(".").all? { |label| /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/i.match?(label) }
	end

	private def uri_template?(value)
		uri?(value.gsub(/\{[^}]*\}/, "template"), absolute: false)
	end

	private def regex?(value)
		::Regexp.new(value)
		true
	rescue ::RegexpError
		false
	end
end
