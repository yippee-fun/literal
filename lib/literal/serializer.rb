# frozen_string_literal: true

require "json"

class Literal::Serializer
	extend Literal::Types
	include Literal::Types

	def initialize(context)
		@context = context
	end

	# Shallow dispatch check: is this node structurally one of ours? This must
	# not recurse into child types — the context's serializability walk owns all
	# recursion. Serializers with structured kinds override this with a purely
	# structural match; the default covers scalar serializers whose type is a
	# plain Literal type.
	def handles_type?(type)
		within_domain?(type, self.type) || const_type?(type)
	end

	# Whether deserializing a value of the domain gives a value of the type.
	# Being frozen is representation, not data, so a type that requires it
	# needs a domain whose values are always frozen.
	private def within_domain?(type, domain)
		case type
		in Literal::Types::UnionType
			type.all? { |member| within_domain?(member, domain) }
		else
			frozen = Literal::Types::FrozenType::Anything

			Literal.subtype?(type, domain) &&
				(!Literal.subtype?(type, frozen) || Literal.subtype?(domain, frozen))
		end
	end

	# A const type — a literal value of this serializer's domain, or a union of
	# such values — serializes by its canonical representation. The value-set of
	# the type 1 is not bounded by Integer (1 admits 1.0 via ==), but the wire
	# format of the value 1 is an integer all the same.
	private def const_type?(type)
		case type
		when Literal::Types::UnionType
			members = type.to_a
			members.any? && members.all? { |member| self.type === member }
		else
			self.type === type
		end
	end

	# The child types this serializer would recurse into when serializing a
	# value of the given type. These must be exactly the types serialize,
	# deserialize and json_schema recurse into, so that the serializability walk
	# agrees with what actually happens.
	def child_types(type)
		[]
	end

	# Whether a node of this type may be the target of a JSON Schema "$ref" —
	# which is also what makes recursion through it legal.
	def referenceable?(type)
		false
	end

	# The top-level JSON type ("string", "integer", …) of the schema this
	# serializer emits for the given type, or nil when there isn't a single one.
	def json_type(type)
		nil
	end

	# The key shape of the closed JSON object schema this serializer emits for
	# the given type, or nil when its schema is not a closed object — open
	# hashes included, since an unbounded key set proves nothing.
	def object_shape(type)
		nil
	end

	# A sentence explaining why this serializer refuses the given type, or nil
	# when it handles the type or has nothing specific to say. Only consulted
	# on the error path, to enrich unserializable type messages.
	def rejection_reason(type)
		nil
	end

	def serialize_contents(value, type:)
		@context.serialize(value, type:, strict: false)
	end

	def deserialize_contents(value, type:)
		@context.deserialize(value, type:, strict: false)
	end

	def json_schema_for(type, generator:, reference: true)
		generator.schema(type, reference:)
	end

	# The serializer that would handle the type if this one were not
	# registered: the next matching serializer in the context's chain. This
	# lets a custom serializer transform a value and delegate the remaining
	# work, like calling super. Any protocol method can be forwarded to it —
	# child_types, referenceable? and object_shape included, which delegating
	# serializers should usually forward so the serializability walk and union
	# discrimination see through them.
	def super_serializer(type)
		@context.serializer_for_type(type, after: self)
	end

	def super_serialize(value, type:)
		super_serializer(type).serialize(value, type:)
	end

	# Applies the next serializer's raw value coercion before deserializing,
	# just as the context would if that serializer had handled the type.
	def super_deserialize(raw, type:)
		serializer = super_serializer(type)
		serializer.deserialize(serializer.coerce(raw), type:)
	end

	def super_json_schema(type, generator: nil)
		super_serializer(type).json_schema(type, generator:)
	end

	def value_type(value)
		type if type === value
	end

	def mergeable_object?(type)
		false
	end

	# This gives you an opportunity to coerce raw values before type checking and deserialization.
	def coerce(raw)
		raw
	end

	# A key under which raw JSON values compare the way JSON Schema compares
	# them: numbers by value at any depth, so 1 and 1.0 are the same value, and
	# so are [1] and [1.0]. A Float is written as its shortest decimal, so it
	# means that decimal's exact value: 1e24 is 10**24, though the Float
	# itself is a little less.
	def self.json_equality_key(value)
		case value
		in Float if value.finite?
			number = Rational(value.to_s)
			(number.denominator == 1) ? number.numerator : number
		in Array
			value.map { |item| json_equality_key(item) }
		in Hash
			value.to_h { |key, item| [key, json_equality_key(item)] }
		else
			value
		end
	end

	# Sorts the keys of every object within serialized JSON data, at every
	# depth. Arrays keep their order.
	def self.sort_keys(value)
		case value
		when Hash
			if value.compare_by_identity?
				# Identity hashes can repeat a key, so entries sharing a key sort
				# canonically among themselves.
				sorted = {}.compare_by_identity
				value.group_by { |key, _| key }.sort_by { |key, _| key }.each do |_, entries|
					sort_canonically(entries).each { |key, item| sorted[key] = sort_keys(item) }
				end
				sorted
			else
				value.sort_by { |key, _| key }.to_h { |key, item| [key, sort_keys(item)] }
			end
		when Array
			value.map { |item| sort_keys(item) }
		else
			value
		end
	end

	# Sorts serialized elements whose order carries no meaning — set members
	# and hash entry pairs — by their canonical JSON encoding, so they
	# serialize predictably regardless of insertion order. Elements JSON can't
	# encode sort after those it can, and ties break on the elements' Marshal
	# bytes, or failing that their inspection, so the order is total.
	def self.sort_canonically(elements)
		return elements if elements.size < 2

		elements
			.map { |element| [canonical_sort_key(element), element] }
			.sort { |(a_key, a), (b_key, b)| (a_key <=> b_key).nonzero? || (tiebreak_sort_key(a) <=> tiebreak_sort_key(b)) }
			.map(&:last)
	end

	# Elements haven't been validated yet — the strict check runs on the
	# finished payload — and invalid ones can run user code (to_json, _dump,
	# inspect), so neither key may raise, leaving that check to report them.
	# JSON data has no nesting limit, so neither does the encoding.
	def self.canonical_sort_key(element)
		[0, JSON.generate(sort_keys(element), max_nesting: false)]
	rescue
		[1, ""]
	end

	def self.tiebreak_sort_key(element)
		sorted = sort_keys(element)

		begin
			Marshal.dump(sorted)
		rescue
			sorted.inspect
		end
	rescue
		""
	end

	private_class_method :canonical_sort_key, :tiebreak_sort_key

	private def sort_canonically(elements)
		Literal::Serializer.sort_canonically(elements)
	end

	private def json_type_for(type)
		@context.json_type(type)
	end

	# Deserializers check the JSON shape they read on entry, so malformed input
	# raises this rather than whatever the reading code happens to raise.
	private def malformed_raw_error(raw, type)
		Literal::ArgumentError.new("Value #{raw.inspect} cannot be deserialized as #{type.inspect}")
	end

	# Whether the type is a union containing Literal::Undefined, marking a
	# property or shape key that is omitted when serializing an undefined value
	# and restored to Literal::Undefined when its key is missing.
	private def undefined_optional?(type)
		Literal::Types::UnionType === type && type.optional?
	end

	# The type an undefined-optional value serializes as when it is present.
	# Literal::Undefined is never serialized as a standalone value — it only
	# exists as the absence of a key — so it is stripped before recursing.
	private def without_undefined(type)
		return type unless undefined_optional?(type)

		type.reject { |member_type| member_type == Literal::Undefined }
	end

	private def apply_length_constraints(schema, property_constraints, min_key:, max_key:)
		property_constraints.each do |property, constraint|
			case [property, constraint]
			in [:length | :size, Range]
				apply_length_range(schema, constraint, min_key:, max_key:)
			in [:length | :size, Integer]
				apply_length_range(schema, constraint..constraint, min_key:, max_key:)
			else
				# Constraints JSON Schema cannot express are ignored. The schema is
				# looser than the type, but still accepts everything serialization
				# produces, since serialized values are checked against the type.
			end
		end
	end

	# Lengths are whole and never negative, so bounds round inward, a minimum
	# below zero says nothing, and a maximum below zero admits nothing.
	private def apply_length_range(schema, range, min_key:, max_key:)
		minimum = finite_bound(range.begin)
		maximum = finite_bound(range.end)

		schema[min_key] = [minimum.ceil, 0].max if minimum

		if maximum
			maximum = range.exclude_end? ? maximum.ceil - 1 : maximum.floor

			if maximum < 0
				schema["not"] = {}
			else
				schema[max_key] = maximum
			end
		end
	end

	# JSON has no infinite numbers, and an infinite bound is no bound at all.
	private def finite_bound(bound)
		bound if Numeric === bound && bound.finite?
	end

	# JSON generators write only Integers and Floats as numbers, so a bound
	# of another class is written as one when that's exact, and left out
	# otherwise: the schema is looser, but still accepts every value.
	private def json_bound(bound)
		case finite_bound(bound)
		in nil | Integer | Float => number
			number
		in number unless number.real?
			nil
		in number if number == number.truncate
			number.truncate
		in number if number.to_f.finite? && number.to_r == number.to_f.to_r
			number.to_f
		else
			nil
		end
	end

	private def apply_range_constraints(schema, ranges)
		minimum, maximum, exclusive_maximum = narrowed_range_bounds(ranges)

		schema["minimum"] = minimum unless minimum.nil?

		unless maximum.nil?
			if exclusive_maximum
				schema["exclusiveMaximum"] = maximum
			else
				schema["maximum"] = maximum
			end
		end
	end

	private def narrowed_range_bounds(ranges)
		minimum = nil
		maximum = nil
		exclusive_maximum = false

		ranges.each do |range|
			range_begin = json_bound(range.begin)
			range_end = json_bound(range.end)

			minimum = range_begin if !range_begin.nil? && (minimum.nil? || range_begin > minimum)

			next if range_end.nil?

			if maximum.nil? || range_end < maximum
				maximum = range_end
				exclusive_maximum = range.exclude_end?
			elsif range_end == maximum && range.exclude_end?
				exclusive_maximum = true
			end
		end

		[minimum, maximum, exclusive_maximum]
	end
end
