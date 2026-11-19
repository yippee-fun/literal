# frozen_string_literal: true

# @api private
module Literal::Freezing
	extend self

	# A frozen version of a loaded value, for types that require frozen values.
	# Plain data (strings, arrays, hashes and sets) is frozen all the way down,
	# copying anything not already frozen, so the raw input it may share is
	# never mutated. Any other object is frozen by its own #freeze, and left as
	# it is when nested in plain data.
	def deep_frozen(value)
		case value
		when String, Array, Hash, Set
			frozen_data(value)
		else
			value.freeze
		end
	end

	private def frozen_data(value)
		case value
		when String
			value.frozen? ? value : value.dup.freeze
		when Array, Set
			value.dup.map! { |item| frozen_data(item) }.freeze
		when Hash
			# A copy keeps the hash's default and key comparison.
			value.each_with_object(value.dup.clear) do |(key, item), copy|
				copy[frozen_data(key)] = frozen_data(item)
			end.freeze
		else
			value
		end
	end
end
