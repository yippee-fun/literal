# frozen_string_literal: true

class Literal::Checks::Collector
	def initialize
		@errors = []
		@tainted = Set.new
		@defaulted = Set.new
		@unknown_keys = false
	end

	attr_reader :errors

	# Whether an error has been filed against this property. Whole-value
	# failures are filed against no property and taint nothing.
	def tainted?(name)
		@tainted.include?(name)
	end

	# A phantom value is the shape's own invention — a default resolved for an
	# ungiven prop — standing where a mistyped key's value may have been meant
	# to go. It exists only once a key named no prop: with every key understood,
	# a default is legitimate and checks judge it like any other value.
	def phantom?(name)
		@unknown_keys && @defaulted.include?(name)
	end

	def defaulted(name)
		@defaulted << name
	end

	def add(prop = nil, message)
		push(prop, message, prop ? [prop] : [])
	end

	def add_unknown(key)
		@unknown_keys = true
		add_about_key(key, Literal::Checks::Message::UNKNOWN)
	end

	# No flag: filing against the prop's own name taints it, which already
	# holds back exactly the checks that would read the ambiguous value.
	def add_duplicate(key)
		add_about_key(key, Literal::Checks::Message::DUPLICATE)
	end

	def merge(nested_errors, under:)
		nested_errors.each { |error| push(under, error.message, [under, *error.path]) }
	end

	def any? = @errors.any?

	def to_errors
		Literal::Checks::Errors.new(errors: @errors)
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
		@errors << Literal::Checks::Error.new(prop:, message:, path:)
	end
end
