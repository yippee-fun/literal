# frozen_string_literal: true

require "date"

# @api private
#
# Writes the message for a value that failed its prop's type, keyed by the type
# so every prop using it reads the same way.
#
# Only a public vocabulary is spoken: the NOUNS primitives, booleans, arrays,
# and constraint qualifiers. Any other type — a union, a custom class — reads
# as NOT_ALLOWED, so a message never names or enumerates type structure that
# may not be public.
module Literal::Validations::Message
	extend self

	MISSING = "is missing"
	NOT_ALLOWED = "is not allowed"

	# A key the shape has no prop for. Not "unexpected" — a rule may later want
	# that for a field this shape knows but will not take here.
	UNKNOWN = "is not a known field"

	# Nested past the depth validate will follow.
	TOO_DEEP = "is nested too deeply"

	# Two spellings of one name, so which value was meant is not knowable.
	DUPLICATE = "was given more than once"

	NOUNS = {
		String => "a string",
		Integer => "an integer",
		Float => "a float",
		Numeric => "a number",
		Hash => "a hash",
		Array => "an array",
		Symbol => "a symbol",
		Date => "a date",
		Time => "a time",
	}.freeze

	# The units a count constraint reads in. A constrained property outside this
	# table has no public wording, so a value that breaks it falls back to the
	# base type rather than being told something invented for it.
	COUNTS = { length: "character", size: "item" }.freeze

	# The value decides which part of a constrained type to name: `_String(length: 1..)`
	# given a number has the wrong type; given "" it is empty.
	def for(type, value)
		description = describe(type, value)

		description ? "must be #{description}" : NOT_ALLOWED
	end

	# The description of what the value must be, or nil for a type outside the
	# public vocabulary — a union deliberately has no description, so its members
	# are never enumerated.
	private def describe(type, value)
		case type
		when Literal::Types::NilableType
			# Nilable says the prop may be omitted, not what it must be.
			describe(type.type, value)
		when Literal::Types::FrozenType
			# Frozen fixes the representation, not what the value must be.
			describe(type.type, value)
		when Literal::Types::UnionType
			# A union of the author's own members stays undescribed, so they are
			# never enumerated. The one `prop?` builds is not that: its extra
			# member is Literal's own sentinel, so describing the real member
			# leaks nothing — and every optional prop would read as
			# NOT_ALLOWED otherwise.
			describe_optional(type, value)
		when Literal::Types::ConstraintType
			describe_constraint(type, value)
		when Literal::Types::DeferredType
			# How a shape names itself. Materialized here for the same reason the
			# validator materializes it — otherwise every recursive prop reads as
			# NOT_ALLOWED. Answers nothing while materializing, rather than
			# recurring into itself.
			materialized = type.materialize
			describe(materialized, value) unless materialized.equal?(type)
		when Literal::Types::BooleanType
			"a boolean"
		when Literal::Types::ArrayType
			describe_array(type, value)
		when Literal::Types::HashType
			"a hash"
		when Literal::Types::SetType
			"a set"
		when Literal::Types::TupleType
			"a tuple"
		when Literal::Types::MapType
			"a hash"
		when Literal::Types::EnumerableType
			"a list"
		when Literal::Types::RangeType
			"a range"
		when Class, Module
			NOUNS[type] || describe_object(type, value)
		end
	end

	# A shape reads as "an object" only when the caller sent something that
	# plainly is not one — a scalar where a nested value belongs. A Hash, a
	# draft, or another shape's value already is an object, and saying which one
	# it should have been would name a class that may be internal.
	private def describe_object(type, value)
		return nil unless type < Literal::DataStructure
		return nil if Hash === value || Literal::Draft === value || Literal::DataStructure === value

		"an object"
	end

	# `prop? :name, String` types the prop `_Union(String, Literal::Undefined)`.
	# The sentinel means "may be omitted", not something the value must be, so
	# it is dropped and what is left is described — but only when dropping it
	# leaves exactly one member, since anything more is a real union. A nil
	# primitive is tolerated the way NilableType is above: `prop? :name,
	# _Nilable(String)` flattens nil into the union's primitives, and nil says
	# the prop may be empty, not what it must be.
	private def describe_optional(type, value)
		return nil unless type.optional?

		members = type.types.reject { |member| Literal::Undefined == member }

		describe(members.first, value) if members.size == 1 && type.primitives.all?(&:nil?)
	end

	# A constrained type is a base type plus what else must hold of the value:
	# `_Integer(1..100)` is `[Integer, 1..100]`, `_String(length: 1..)` is `[String]`
	# with `{length: 1..}`. A value of the wrong base type is told that; once the base
	# holds, the qualifier is what to name.
	private def describe_constraint(type, value)
		base = type.object_constraints.find { |constraint| Module === constraint }

		return describe(base, value) if base && !(base === value)

		# Only the qualifiers the value actually breaks: naming one it already
		# satisfies says something flatly untrue — "zzz" told it must be filled.
		qualifiers = type.object_constraints.grep(Range)
			.reject { |range| range === value }
			.filter_map { |range| bound = bounds(range); bound unless bound.empty? }

		type.property_constraints.each do |property, constraint|
			next if constraint === measure(value, property)

			counted = count_of(property, constraint)
			qualifiers << counted if counted
		end

		if type.object_constraints.grep(Regexp).any? { |pattern| !(pattern === value) }
			described = base && describe(base, value)
			qualifiers << (described ? "#{described} in the expected format" : "in the expected format")
		end

		return qualifiers.join(" and ") if qualifiers.any?

		base && describe(base, value)
	end

	# A value that is not an array is told so; an array is told what its members
	# must be, worded from the first member that does not fit — unless the member
	# type has no public description, in which case neither does the array.
	private def describe_array(type, value)
		return "an array" unless Array === value

		member = value.find { |element| !(type.type === element) }
		description = describe(type.type, member)

		description && "an array where each member is #{description}"
	end

	private def bounds(range, unit = nil)
		suffix = unit ? " #{unit}" : ""
		min = range.begin
		max = range.end

		# An exclusive Integer bound has an inclusive equivalent; anything else
		# has to be worded as exclusive rather than claimed as inclusive.
		if max && range.exclude_end?
			return (Integer === max) ? bounded(min, max - 1, suffix) : exclusive(min, max, suffix)
		end

		bounded(min, max, suffix)
	end

	private def bounded(min, max, suffix)
		if min && max then "between #{min} and #{max}#{suffix}"
		elsif min then "at least #{min}#{suffix}"
		elsif max then "at most #{max}#{suffix}"
		else "" # A range bounded at neither end asks nothing of the value.
		end
	end

	private def exclusive(min, max, suffix)
		min ? "at least #{min}#{suffix} and less than #{max}#{suffix}" : "less than #{max}#{suffix}"
	end

	# What the value answers for a constrained property, or nil when it cannot
	# answer at all. That is how Literal::Types::ConstraintType reads it too, so
	# a value with no `#length` is told what was wanted rather than raising out
	# of validate — which a message, written for input the type check has already
	# refused, must never do.
	private def measure(value, property)
		value.public_send(property) if value.respond_to?(property)
	end

	# `length: 1..` reads as `filled`, `length: 5` as `exactly 5 characters`. A
	# count's exclusive end always has an inclusive equivalent, so it is always
	# worded inclusively. A constraint that is not a count of a known unit has no
	# public wording, and gets none.
	private def count_of(property, constraint)
		unit = COUNTS[property]
		return nil unless unit
		return exactly(constraint, unit) if Integer === constraint
		return nil unless Range === constraint

		min = constraint.begin
		max = constraint.end
		max -= 1 if max && constraint.exclude_end?

		return "filled" if min == 1 && max.nil?
		return exactly(min, unit) if min == max

		bound = bounded(min, max, " #{unit}s")
		bound unless bound.empty?
	end

	private def exactly(count, unit)
		"exactly #{count} #{unit}#{'s' unless count == 1}"
	end
end
