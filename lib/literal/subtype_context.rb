# frozen_string_literal: true

class Literal::SubtypeContext
	Frame = Data.define(:structural_depth, :index, :outer_assumption_floor)

	def initialize
		@memo = {}
		@in_progress = {}
		@structural_depth = 0
		@assumption_floor = Float::INFINITY
	end

	attr_reader :memo, :in_progress

	def memoized?(key)
		@memo.key?(key)
	end

	def fetch(key)
		@memo[key]
	end

	# A result that relied on an assumption about a pair still being proven
	# further up the stack is provisional: that pair may yet fail, so it is
	# not memoized.
	def store(key, result)
		@memo[key] = result unless @assumption_floor < @in_progress.fetch(key).index
	end

	def acquire(key)
		return false if @in_progress.key?(key)

		@in_progress[key] = Frame.new(@structural_depth, @in_progress.size, @assumption_floor)
		@assumption_floor = Float::INFINITY
		true
	end

	def release(key)
		frame = @in_progress.delete(key)
		@assumption_floor = Float::INFINITY if @assumption_floor >= frame.index
		@assumption_floor = frame.outer_assumption_floor if frame.outer_assumption_floor < @assumption_floor
	end

	# Coinductive assumption for a pair we are already in the middle of proving.
	# Only sound if we have descended through at least one structural constructor
	# since first visiting the pair (i.e. the recursion is contractive). A cycle
	# reached purely through transparent types (unions, nilables, deferreds) makes
	# no progress and must not be assumed.
	def assume(key)
		frame = @in_progress[key]
		@assumption_floor = frame.index if frame.index < @assumption_floor
		@structural_depth > frame.structural_depth
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
