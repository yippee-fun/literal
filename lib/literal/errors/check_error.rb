# frozen_string_literal: true

# Raised when every value fits its property's type but the shape's own checks
# do not hold. Deliberately does not carry the offending object: checks are the
# shape's invariant, so an object that breaks them is never handed out.
class Literal::CheckError < StandardError
	include Literal::Error

	def self.raise_trimmed(shape:, errors:)
		error = new(shape:, errors:)
		error.set_backtrace(Literal::Error.trim(caller_locations(1)))
		raise error
	end

	def initialize(shape:, errors:)
		@shape = shape
		@errors = errors
		super()
	end

	attr_reader :shape, :errors

	def message
		buffer = +"Unsound #{@shape.name || @shape.inspect}\n"

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
