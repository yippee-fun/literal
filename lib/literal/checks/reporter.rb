# frozen_string_literal: true

# Handed to a reporting check (`checks { |errors, ...| }`). `add` files a
# failure against a property, or against the value as a whole when none is
# given. A name the shape being checked does not have — a typo, or a property a
# slice dropped — is the check's own bug, so it raises rather than filing an
# error nobody could read.
class Literal::Checks::Reporter
	def initialize(shape, collector)
		@shape = shape
		@collector = collector
	end

	def add(prop = nil, message)
		unless prop.nil? || @shape.literal_properties[prop]
			raise Literal::ArgumentError.new(
				"#{@shape.name || 'This shape'} has no #{prop.inspect} property for a check to report against"
			)
		end

		unless String === message
			raise Literal::ArgumentError.new("A check's message is a String, got #{message.class}")
		end

		@collector.add(prop, message)
		nil
	end
end
