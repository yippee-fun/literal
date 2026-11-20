# frozen_string_literal: true

# What a _Pattern predicate matches: a value the regex matches, whose captures
# the block accepts. An object rather than a closure, because
# Ractor.make_shareable only makes the block shareable when it reaches it
# through an instance variable.
class Literal::Types::PatternMatcher
	def initialize(regex, block)
		@regex = regex
		@block = block
		freeze
	end

	def ===(value)
		if (data = @regex.match(value))
			!!@block.call(*data.captures, **data.named_captures&.transform_keys(&:to_sym))
		else
			false
		end
	end
end
