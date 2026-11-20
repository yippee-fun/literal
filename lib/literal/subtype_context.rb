# frozen_string_literal: true

# Pairs are keyed by the object ids of each side, so a type's own == and
# hash are never consulted. A pair's entry is its memoized result, or the
# index of its frame while it is being proven.
class Literal::SubtypeContext
	# Progress is one Integer, so a frame records it in one slot: the
	# structural depth in its low bits and the left unfold count above them.
	LeftUnfold = 1 << 24
	StructuralDepth = LeftUnfold - 1

	# Far more unfolds than any check makes, so lowering the count by it puts
	# it below every outer frame's.
	SwappedSides = LeftUnfold << 24

	def initialize
		@pairs = {}
		@frames = []
		@progress = 0
		@assumption_floor = Float::INFINITY
		@unfold_assumptions = nil
	end

	# The memoized result for a pair, the assumption for a pair still being
	# proven, or nil for a pair not yet visited.
	def recall(subtype_id, supertype_id, subtype)
		case @pairs[subtype_id]&.[](supertype_id)
		in Integer => frame then assume(frame, subtype)
		in entry then entry
		end
	end

	# Returns the new frame's index. Each frame holds the progress it started
	# at and the assumption floor of the frame around it.
	def acquire(subtype_id, supertype_id)
		frame = @frames.size / 2
		(@pairs[subtype_id] ||= {})[supertype_id] = frame
		@frames.push(@progress, @assumption_floor)
		@assumption_floor = Float::INFINITY
		frame
	end

	# A result that relied on an assumption about a pair still being proven
	# further up the stack is provisional: that pair may yet fail, so it is
	# not memoized. A proof resting on an unfold assumption its type turned
	# out not to support stores nothing and answers nil, to be tried again
	# refusing it.
	def store(subtype_id, supertype_id, frame, result)
		if @unfold_assumptions && !@unfold_assumptions.empty?
			if result && !confirmed?(frame)
				settle_unfold_assumptions(frame, false)
				return nil
			end

			settle_unfold_assumptions(frame, result)
		end

		@pairs[subtype_id][supertype_id] = result unless @assumption_floor < frame
		result
	end

	# Unfolds made while proving a pair end with it.
	def release(subtype_id, supertype_id, frame)
		supertypes = @pairs[subtype_id]

		if Integer === supertypes[supertype_id]
			supertypes.delete(supertype_id)
			@pairs.delete(subtype_id) if supertypes.empty?
		end

		outer_assumption_floor = @frames.pop
		@progress = @frames.pop
		@assumption_floor = Float::INFINITY if @assumption_floor >= frame
		@assumption_floor = outer_assumption_floor if outer_assumption_floor < @assumption_floor
	end

	# An unfold lasts until the pair being proven is released.
	def unfold_left(type)
		@progress += LeftUnfold
		type.materialize
	end

	# Whether a deferred type's materialization is a subtype of the given
	# type, counting the step as a left unfold for that check alone.
	def left_unfolded_subtype?(type, supertype)
		@progress += LeftUnfold
		result = Literal.subtype?(type.materialize, supertype, context: self)
		@progress -= LeftUnfold
		result
	end

	# Marks descent into a component of a structural constructor (array element,
	# hash key/value, tuple slot, etc.) for the duration of the block.
	def structural
		@progress += 1
		yield
	ensure
		@progress -= 1
	end

	# A check whose sides are swapped relative to the caller's, as _Not(A) <=
	# _Not(B) asks B <= A. Its left side was the caller's right, so no cycle
	# through it counts as unfolding the left. If it raises, the count stays
	# lowered only until the caller's pair is released.
	def contravariant_subtype?(type, supertype)
		@progress -= SwappedSides
		result = Literal.subtype?(type, supertype, context: self)
		@progress += SwappedSides
		result
	end

	# Park induction needs the left type's least fixpoint, so a pair proven by
	# assuming it through a left unfold holds only if that type refers to
	# itself positively. This is checked once the pair is otherwise proven, so
	# a failing check never forces deferred types it doesn't need.
	# The only frame still open after this one is that of the pair it
	# resolved to, so the assumptions on frames from this one on rest on
	# this proof.
	private def confirmed?(frame)
		assumptions = @unfold_assumptions
		confirmed = true
		i = 0

		while i < assumptions.size
			if assumptions[i] >= frame
				confirmed &&= positive?(assumptions[i + 1])
				assumptions.slice!(i, 3)
			else
				i += 3
			end
		end

		confirmed
	end

	# Coinductive assumption for a pair we are already in the middle of proving.
	# It is sound if the cycle descended through a structural constructor (the
	# recursion is contractive), or if it unfolded the left side: a recursive
	# type on the left stands for its least fixpoint, which is a subtype of
	# whatever its unfolding is (Park induction). Unfolding only the right
	# side, like String against μY.Y, proves nothing.
	private def assume(frame, left)
		@assumption_floor = frame if frame < @assumption_floor
		started = @frames[frame * 2]

		return true if (@progress & StructuralDepth) > (started & StructuralDepth)
		return false unless @progress / LeftUnfold > started / LeftUnfold
		return false if known_negative?(left)

		(@unfold_assumptions ||= []).push(frame, left, @frames.size / 2)
		true
	end

	# Each unfold assumption records how many frames were open when it was
	# made. A failed proof supports nothing, so the assumptions made during it
	# need no confirmation; a successful one hands them to the frame around it.
	private def settle_unfold_assumptions(frame, result)
		assumptions = @unfold_assumptions
		i = 0

		while i < assumptions.size
			if assumptions[i + 2] <= frame
				i += 3
			elsif result
				assumptions[i + 2] = frame
				i += 3
			else
				assumptions.slice!(i, 3)
			end
		end
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
end
