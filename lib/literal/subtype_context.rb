# frozen_string_literal: true

# Pairs are keyed by the object ids of each side, so a type's own == and
# hash are never consulted. A pair's entry is its memoized result, or the
# index of its frame while it is being proven.
class Literal::SubtypeContext
	def initialize
		@pairs = {}
		@frames = []
		@structural_depth = 0
		@assumption_floor = Float::INFINITY
	end

	# The memoized result for a pair, the assumption for a pair still being
	# proven, or nil for a pair not yet visited.
	def recall(subtype_id, supertype_id)
		case @pairs[subtype_id]&.[](supertype_id)
		in Integer => frame then assume(frame)
		in entry then entry
		end
	end

	# Returns the new frame's index. Each frame holds the structural depth
	# it started at and the assumption floor of the frame around it.
	def acquire(subtype_id, supertype_id)
		frame = @frames.size / 2
		(@pairs[subtype_id] ||= {})[supertype_id] = frame
		@frames.push(@structural_depth, @assumption_floor)
		@assumption_floor = Float::INFINITY
		frame
	end

	# A result that relied on an assumption about a pair still being proven
	# further up the stack is provisional: that pair may yet fail, so it is
	# not memoized.
	def store(subtype_id, supertype_id, frame, result)
		@pairs[subtype_id][supertype_id] = result unless @assumption_floor < frame
	end

	def release(subtype_id, supertype_id, frame)
		supertypes = @pairs[subtype_id]

		if Integer === supertypes[supertype_id]
			supertypes.delete(supertype_id)
			@pairs.delete(subtype_id) if supertypes.empty?
		end

		outer_assumption_floor = @frames.pop
		@frames.pop
		@assumption_floor = Float::INFINITY if @assumption_floor >= frame
		@assumption_floor = outer_assumption_floor if outer_assumption_floor < @assumption_floor
	end

	# Coinductive assumption for a pair we are already in the middle of proving.
	# Only sound if we have descended through at least one structural constructor
	# since first visiting the pair (i.e. the recursion is contractive). A cycle
	# reached purely through transparent types (unions, nilables, deferreds) makes
	# no progress and must not be assumed.
	private def assume(frame)
		@assumption_floor = frame if frame < @assumption_floor
		@structural_depth > @frames[frame * 2]
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
