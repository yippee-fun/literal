# frozen_string_literal: true

class Literal::Types::UnionType
	include Enumerable
	include Literal::Type
	include Literal::Types::DraftTransparent

	def initialize(queue)
		raise Literal::ArgumentError.new("_Union type must have at least one type.") if queue.size < 1
		types = []
		primitives = Set[]

		while queue.length > 0
			type = queue.shift
			# Flattened members are queued at the front so that they take the
			# position of the member they came from — order decides how JSON
			# schemas list them and which of two incomparable members `resolve`
			# picks.
			case type
			when Literal::Types::UnionType
				queue.unshift(*type.types, *type.primitives)
			when Literal::Types::NilableType
				# A nilable member is the same as its type plus nil, and flattening it
				# is what makes `_Optional(_Nilable(String))` and
				# `_Nilable(_Optional(String))` the same union.
				queue.unshift(type.type, nil)
			when Array, Hash, String, Symbol, Integer, Float, Complex, Rational, true, false, nil
				primitives << type
			else
				types << type
			end
		end

		types.uniq!
		@types = types.freeze
		@primitives = primitives.freeze
		@primitive_list = primitives.to_a.freeze
		@hash = [Literal::Types::UnionType, @types, @primitive_list].hash
		@guarded = Literal::Types::UnionType.reaches_opaque_match?(types)

		freeze
	end

	attr_reader :types, :primitives, :hash

	protected attr_reader :primitive_list

	# The earliest of the matching members, in declaration order, that no other
	# is a strict subtype of. Only matches are compared, so a deferred member
	# is never materialized unless the value matched it.
	def self.most_specific(matches)
		matches.find do |match|
			type = yield match
			matches.none? { |other| strict_subtype?(yield(other), type) }
		end or raise Literal::ArgumentError.new("No most specific member of #{matches.inspect}: they are strict subtypes of one another in a cycle.")
	end

	# Whether matching any of these types can run opaque code — a proc, or an
	# object or module with its own `===` — without first passing a deferred
	# type's guard. Opaque code can re-enter the match, so a union that reaches
	# it needs a guard of its own.
	def self.reaches_opaque_match?(types, seen = {}.compare_by_identity)
		types.any? do |type|
			next false if seen.key?(type)

			seen[type] = true

			case type
			in Literal::Types::DeferredType
				false
			in Literal::Type
				reaches_opaque_match?(type.literal_child_types, seen)
			in Module
				Module != Literal::METHOD.bind_call(type, :===).owner
			in String | Symbol | Numeric | Regexp | Range | ::Array | ::Hash | true | false | nil
				false
			else
				Kernel != Literal::METHOD.bind_call(type, :===).owner
			end
		end
	end

	private_class_method def self.strict_subtype?(type, supertype)
		!type.equal?(supertype) && Literal.subtype?(type, supertype) && !Literal.subtype?(supertype, type)
	end

	def __relax__(&relax)
		Literal::Types._Union(*@types.map(&relax), *@primitives)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		@types.each { |type| yield type }
	end

	# Whether this union contains the exact `Literal::Undefined` object as a
	# member — the shape `_Optional` builds — making a property of this type
	# omittable. Exact containment, not `===`: the sentinel is a truthy object,
	# so types like `_Truthy` merely match it.
	def optional?
		@types.any? { |type| Literal::Undefined.equal?(type) }
	end

	def inspect
		"_Union(#{to_a.map(&:inspect).join(', ')})"
	end

	def ===(value)
		return true if primitive_match?(value)

		if @guarded
			Literal.with_match_guard(self, value) { type_match?(value) }
		else
			type_match?(value)
		end
	end

	private def type_match?(value)
		types = @types

		i, len = 0, types.size
		while i < len
			return true if types[i] === value
			i += 1
		end

		false
	end

	# The member a value belongs to: a primitive it is, or else a most specific
	# matching type, or else a primitive it is merely == to — so
	# BigDecimal("1") resolves to a BigDecimal member before the literal 1.
	def resolve(value)
		return value if primitive_member?(value)

		types = @types

		i, len = 0, types.size
		while i < len
			type = types[i]

			if type === value
				j = i + 1
				while j < len
					return most_specific_type(i, j, value) if types[j] === value
					j += 1
				end

				return type
			end

			i += 1
		end

		index = equal_primitive_index(value)
		raise Literal::ArgumentError.new("No match found for #{value.inspect} in #{inspect}.") unless index

		@primitive_list[index]
	end

	def each(&)
		if block_given?
			@primitives.each(&)
			@types.each(&)
		else
			Enumerator.new do |yielder|
				@primitives.each { |primitive| yielder.yield(primitive) }
				@types.each { |type| yielder.yield(type) }
			end
		end
	end

	def deconstruct
		to_a
	end

	# Member order is behaviourally meaningful — `resolve` breaks ties by it and
	# JSON schemas list members in order — but it does not change which values
	# a union admits, so `==` compares members as a set. `@primitives` already
	# does; `@types` is uniqued with eql? by the constructor, so for equal sizes
	# an eql? subset is an equal set. `eql?` (and so hash keys) also requires
	# the same order, like 1 == 1.0 but not 1.eql?(1.0), so unions sharing a
	# key behave alike.
	def eql?(other)
		Literal::Types::UnionType === other && @types.eql?(other.types) && @primitive_list.eql?(other.primitive_list)
	end

	def ==(other)
		case other
		when Literal::Types::UnionType
			@primitives == other.primitives &&
				@types.size == other.types.size &&
				(@types.eql?(other.types) || @types.all? { |type| other.types.any? { |member| member.eql?(type) } })
		else
			false
		end
	end

	def [](key)
		if @primitives.include?(key) || @types.include?(key)
			key
		end
	end

	def fetch(key)
		self[key] or raise KeyError.new("Key not found: #{key.inspect}")
	end

	def map(&)
		Literal::Types::UnionType.new([*@primitives.map(&), *@types.map(&)])
	end

	def reject(&)
		members = to_a.reject(&)

		case members.size
		when 0
			Literal::Types::NeverType::Instance
		when 1
			members.first
		else
			Literal::Types::UnionType.new(members)
		end
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::FalsyType
			covers?(nil, context:) && covers?(false, context:)
		else
			covers?(other, context:)
		end
	end

	private def covers?(type, context:)
		@primitives.any? { |primitive| Literal.subtype?(type, primitive, context:) } ||
			@types.any? { |member| Literal.subtype?(type, member, context:) }
	end

	# Members `first` and `second` both match; no member between them does.
	private def most_specific_type(first, second, value)
		matches = [@types[first], @types[second], *@types[(second + 1)..].select { |type| type === value }]
		Literal::Types::UnionType.most_specific(matches, &:itself)
	end

	private def primitive_match?(value)
		primitive_member?(value) || !equal_primitive_index(value).nil?
	end

	private def primitive_member?(value)
		@primitives.include?(value)
	rescue
		false
	end

	# Primitives match with ==, like bare literals (1 === 1.0), so a value
	# that isn't eql? to one may still equal one.
	private def equal_primitive_index(value)
		primitives = @primitive_list

		i, len = 0, primitives.size
		while i < len
			return i if primitives[i] == value
			i += 1
		end

		nil
	end

	freeze
end
