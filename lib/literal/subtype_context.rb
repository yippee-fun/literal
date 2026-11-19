# frozen_string_literal: true

class Literal::SubtypeContext
	Frame = Struct.new(:structural_depth, :left_unfolds, :right_unfolds, :contravariant, :index, :outer_assumption_floor)

	def initialize
		@memo = {}
		@in_progress = {}
		@structural_depth = 0
		@left_unfolds = 0
		@right_unfolds = 0
		@contravariant = false
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

		@in_progress[key] = Frame.new(@structural_depth, @left_unfolds, @right_unfolds, @contravariant, @in_progress.size, @assumption_floor)
		@assumption_floor = Float::INFINITY
		true
	end

	# Unfolds made while proving a pair end with it.
	def release(key)
		frame = @in_progress.delete(key)
		@left_unfolds = frame.left_unfolds
		@right_unfolds = frame.right_unfolds
		@assumption_floor = Float::INFINITY if @assumption_floor >= frame.index
		@assumption_floor = frame.outer_assumption_floor if frame.outer_assumption_floor < @assumption_floor
	end

	# Coinductive assumption for a pair we are already in the middle of proving.
	# It is sound if the cycle descended through a structural constructor (the
	# recursion is contractive), or if it unfolded the left side: a recursive
	# type on the left stands for its least fixpoint, which is a subtype of
	# whatever its unfolding is (Park induction). Unfolding only the right
	# side, like String against μY.Y, proves nothing.
	def assume(key)
		frame = @in_progress[key]
		@assumption_floor = frame.index if frame.index < @assumption_floor

		@structural_depth > frame.structural_depth ||
			(@left_unfolds > frame.left_unfolds && @contravariant == frame.contravariant)
	end

	# An unfold lasts until the pair being proven is released.
	def unfold_left(type)
		@left_unfolds += 1
		type.materialize
	end

	def unfold_right(type)
		@right_unfolds += 1
		type.materialize
	end

	# Marks descent into a component of a structural constructor (array element,
	# hash key/value, tuple slot, etc.) for the duration of the block.
	def structural
		@structural_depth += 1
		yield
	ensure
		@structural_depth -= 1
	end

	# Marks a check whose sides are swapped relative to the caller's, like the
	# types inside two _Nots, for the duration of the block.
	def contravariant
		swap_sides
		yield
	ensure
		swap_sides
	end

	private def swap_sides
		@left_unfolds, @right_unfolds = @right_unfolds, @left_unfolds
		@contravariant = !@contravariant
	end
end
