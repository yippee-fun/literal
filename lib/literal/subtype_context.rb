# frozen_string_literal: true

class Literal::SubtypeContext
	def initialize
		@memo = {}
		@in_progress = {}
		@structural_depth = 0
	end

	attr_reader :memo, :in_progress

	def memoized?(key)
		@memo.key?(key)
	end

	def fetch(key)
		@memo[key]
	end

	def store(key, result)
		@memo[key] = result
	end

	def acquire(key)
		return false if @in_progress.key?(key)

		@in_progress[key] = @structural_depth
		true
	end

	def release(key)
		@in_progress.delete(key)
	end

	# Coinductive assumption for a pair we are already in the middle of proving.
	# Only sound if we have descended through at least one structural constructor
	# since first visiting the pair (i.e. the recursion is contractive). A cycle
	# reached purely through transparent types (unions, nilables, deferreds) makes
	# no progress and must not be assumed.
	def assume(key)
		@structural_depth > @in_progress[key]
	end

	# Marks descent into a component of a structural constructor (array element,
	# hash key/value, tuple slot, etc.) for the duration of the block.
	def structural
		@structural_depth += 1
		yield
	ensure
		@structural_depth -= 1
	end
end
