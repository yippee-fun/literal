# frozen_string_literal: true

# The top-level key shape of a closed JSON object schema: which keys it
# requires, which it allows, and — where a key's serialized values form a
# known finite set — which raw values it accepts at that key. Shapes are how
# the union serializer decides whether object members can share an untagged
# union: two shapes no raw object can satisfy at once are safe together, and
# the same evidence resolves a raw object back to its member on the way in.
class Literal::Serializer::ObjectShape
	def initialize(required:, allowed:, const_domains:)
		const_domains.each_value(&:freeze)

		@required = required.freeze
		@allowed = allowed.freeze
		@const_domains = const_domains.freeze

		freeze
	end

	# The set of keys a valid object must contain.
	attr_reader :required

	# The set of all keys a valid object may contain.
	attr_reader :allowed

	# For keys whose value type has a finite serialized domain (such as a
	# constant), the set of raw values the key accepts.
	attr_reader :const_domains

	# Whether no raw object can satisfy both shapes: one requires a key the
	# other's closed key set excludes, or a key they both require accepts
	# disjoint sets of raw values.
	def distinguishable_from?(other)
		requires_key_excluded_by?(other) ||
			other.requires_key_excluded_by?(self) ||
			distinct_const_at_shared_key?(other)
	end

	# Whether a raw object's keys and constant-valued entries fit this shape.
	# Among shapes proven pairwise distinguishable, at most one accepts any
	# given raw object.
	def accepts?(raw)
		@required.all? { |key| raw.key?(key) } &&
			raw.each_key.all? { |key| @allowed.include?(key) } &&
			@const_domains.all? { |key, domain| !raw.key?(key) || domain.include?(raw[key]) }
	end

	protected def requires_key_excluded_by?(other)
		other_allowed = other.allowed

		@required.any? { |key| !other_allowed.include?(key) }
	end

	private def distinct_const_at_shared_key?(other)
		other_domains = other.const_domains

		(@required & other.required).any? do |key|
			domain = @const_domains[key]
			other_domain = other_domains[key]

			domain && other_domain && domain.disjoint?(other_domain)
		end
	end
end
