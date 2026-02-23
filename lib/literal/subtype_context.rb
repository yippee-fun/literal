# frozen_string_literal: true

class Literal::SubtypeContext
	def initialize
		@memo = {}
		@in_progress = {}
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

		@in_progress[key] = true
		true
	end

	def release(key)
		@in_progress.delete(key)
	end
end
