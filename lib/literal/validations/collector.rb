# frozen_string_literal: true

class Literal::Validations::Collector
	def initialize
		@errors = []
		@tainted = Set.new
		@keys_understood = true
	end

	attr_reader :errors

	# Whether an error has been filed against this property. Whole-value
	# failures are filed against no property and taint nothing.
	def tainted?(name)
		@tainted.include?(name)
	end

	# False once a key named no prop or two spellings of one name collided —
	# a rule may otherwise judge a default quietly resolved for a mistyped key.
	def keys_understood?
		@keys_understood
	end

	def add(prop = nil, message)
		push(prop, message, prop ? [prop] : [])
	end

	def add_unknown(key)
		@keys_understood = false
		add_about_key(key, Literal::Validations::Message::UNKNOWN)
	end

	def add_duplicate(key)
		@keys_understood = false
		add_about_key(key, Literal::Validations::Message::DUPLICATE)
	end

	def merge(nested_errors, under:)
		nested_errors.each { |error| push(under, error.message, [under, *error.path]) }
	end

	def any? = @errors.any?

	def to_errors
		Literal::Validations::Errors.new(errors: @errors)
	end

	private def add_about_key(key, message)
		if Symbol === key
			push(key, message, [key])
		else
			push(nil, "#{describe_key(key)} #{message}", [])
		end
	end

	# The key came from outside and this message goes back outside, so only the
	# key's own printable text is used — never an arbitrary object's inspection.
	private def describe_key(key)
		text = case key
			in Symbol | String | Numeric then key.to_s
			else key.class.name || "an object"
		end

		text = text.gsub(/[^[:print:]]/, "").slice(0, 64) || ""
		text.empty? ? "a key" : text
	end

	private def push(prop, message, path)
		@tainted << prop if prop
		@errors << Literal::Validations::Error.new(prop:, message:, path:)
	end
end
