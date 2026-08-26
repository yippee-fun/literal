# frozen_string_literal: true

# Raised when every value fits its property's type but the shape's own
# `stipulate` rules do not hold. Deliberately does not carry the offending
# object: rules are the shape's invariant, so an object that breaks them is
# never handed out.
class Literal::ValidationError < StandardError
	include Literal::Error

	INTERNALS = File.expand_path("../..", __dir__).freeze
	private_constant :INTERNALS

	# Trimmed by path rather than by count, because the paths that raise are
	# different depths. Testing the path alone also catches the codegen's eval
	# frames, whose path is "(eval at .../properties.rb:N)".
	def self.raise_trimmed(shape:, errors:)
		error = new(shape:, errors:)
		frames = caller_locations(1)
		trimmed = frames.drop_while { |location| location.path.include?(INTERNALS) }
		error.set_backtrace((trimmed.empty? ? frames : trimmed).map(&:to_s))
		raise error
	end

	def initialize(shape:, errors:)
		@shape = shape
		@errors = errors
		super()
	end

	attr_reader :shape, :errors

	def message
		buffer = +"Invalid #{@shape.name || @shape.inspect}\n"

		@errors.errors.each do |error|
			label = error.path.join(".")
			buffer << "  " << (label.empty? ? error.message : "#{label} #{error.message}") << "\n"
		end

		buffer
	end

	# Overridden alongside #message, or interpolation, #inspect and any logger
	# that stringifies the error all fall back to the class name.
	def to_s
		message
	end

	def to_h
		{ shape: @shape, errors: @errors }
	end

	def deconstruct_keys(keys)
		to_h
	end
end
