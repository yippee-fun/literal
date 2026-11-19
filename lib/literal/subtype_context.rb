# frozen_string_literal: true

class Literal::SubtypeContext
	Frame = Struct.new(:structural_depth, :left_unfolds, :right_unfolds, :contravariant, :index, :outer_assumption_floor, :unfold_assumptions)

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
	# not memoized. A failed proof supports nothing, so the unfold assumptions
	# made during it need no confirmation.
	def store(key, result)
		frame = @in_progress.fetch(key)
		@memo[key] = result unless @assumption_floor < frame.index
		return if result || @unfold_assumptions.nil?

		@unfold_assumptions.pop while @unfold_assumptions.size > frame.unfold_assumptions
	end

	def acquire(key)
		return false if @in_progress.key?(key)

		@in_progress[key] = Frame.new(
			@structural_depth,
			@left_unfolds,
			@right_unfolds,
			@contravariant,
			@in_progress.size,
			@assumption_floor,
			@unfold_assumptions ? @unfold_assumptions.size : 0,
		)

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
	def assume(key, left)
		frame = @in_progress[key]
		@assumption_floor = frame.index if frame.index < @assumption_floor

		return true if @structural_depth > frame.structural_depth
		return false unless @left_unfolds > frame.left_unfolds && @contravariant == frame.contravariant
		return false if known_negative?(left)

		(@unfold_assumptions ||= []).push(frame, left)
		true
	end

	# Park induction needs the left type's least fixpoint, so a pair proven by
	# assuming it through a left unfold holds only if that type refers to
	# itself positively. This is checked once the pair is otherwise proven, so
	# a failing check never forces deferred types it doesn't need.
	def confirmed?(raw_key, resolved_key)
		assumptions = @unfold_assumptions
		return true if assumptions.nil? || assumptions.empty?

		raw = @in_progress[raw_key]
		resolved = @in_progress[resolved_key]
		confirmed = true
		i = 0

		while i < assumptions.size
			frame = assumptions[i]

			if frame.equal?(raw) || frame.equal?(resolved)
				confirmed &&= positive?(assumptions[i + 1])
				assumptions.delete_at(i)
				assumptions.delete_at(i)
			else
				i += 2
			end
		end

		confirmed
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

	# A type that refers to itself under _Not, like t = _Deferred { _Not(t) },
	# has no least fixpoint, so Park induction says nothing about it. Only
	# references that match the same value count: one inside a container, like
	# _Array(_Not(t)), matches an element, so the recursion is guarded.
	private def positive?(type)
		@positive ||= {}.compare_by_identity
		return @positive[type] if @positive.key?(type)

		@positive[type] = !refers_to_itself_negatively?(type, materialize: true)
	end

	# Refusing a cycle as soon as the deferred types materialized so far show
	# the negative reference leaves the proof free to try another way.
	private def known_negative?(type)
		return !@positive[type] if @positive&.key?(type)
		return false unless refers_to_itself_negatively?(type, materialize: false)

		(@positive ||= {}.compare_by_identity)[type] = false
		true
	end

	private def refers_to_itself_negatively?(root, materialize:)
		positive = {}.compare_by_identity
		negative = {}.compare_by_identity
		pending = [[root, positive]]

		until pending.empty?
			type, seen = pending.pop
			next if seen.key?(type)

			seen[type] = true
			seen = negative.equal?(seen) ? positive : negative if Literal::Types::NotType === type

			each_same_value_child(type, materialize:) do |child|
				return true if negative.equal?(seen) && Literal::EQUAL.bind_call(child, root)

				pending << [child, seen]
			end
		end

		false
	end

	# The types that match the same value as the given type does: a
	# constraint's object constraints match it, but its property constraints
	# match what its methods return.
	private def each_same_value_child(type, materialize:, &)
		case type
		in Literal::Types::DeferredType unless materialize || type.materialized?
			nil
		in Literal::Types::ConstraintType
			type.object_constraints.each(&)
		in Literal::Types::NotType | Literal::Types::DraftTransparent
			type.literal_child_types(&)
		else
			nil
		end
	end

	private def swap_sides
		@left_unfolds, @right_unfolds = @right_unfolds, @left_unfolds
		@contravariant = !@contravariant
	end
end
