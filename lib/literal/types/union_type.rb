# frozen_string_literal: true

class Literal::Types::UnionType
	include Enumerable
	include Literal::Type

	def initialize(queue)
		raise Literal::ArgumentError.new("_Union type must have at least one type.") if queue.size < 1
		types = []
		primitives = Set[]

		while queue.length > 0
			type = queue.shift
			case type
			when Literal::Types::UnionType
				queue.concat(type.types, type.primitives.to_a)
			when Array, Hash, String, Symbol, Integer, Float, Complex, Rational, true, false, nil
				primitives << type
			else
				types << type
			end
		end

		types.uniq!
		@types = types.freeze
		@primitives = primitives.freeze

		freeze
	end

	attr_reader :types, :primitives

	def literal_child_types
		return enum_for(__method__) unless block_given?

		@types.each { |type| yield type }
	end

	def inspect
		"_Union(#{to_a.map(&:inspect).join(', ')})"
	end

	def ===(value)
		return true if primitive_match?(value)

		Literal.with_match_guard(self, value) do
			types = @types

			i, len = 0, types.size
			while i < len
				return true if types[i] === value
				i += 1
			end

			false
		end
	end

	def resolve(value)
		if @primitives.include?(value)
			value
		else
			types = @types

			i, len = 0, types.size
			while i < len
				type = types[i]
				return type if type === value
				i += 1
			end

			raise Literal::ArgumentError.new("No match found for #{value.inspect} in #{inspect}.")
		end
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

	def ==(other)
		case other
		when Literal::Types::UnionType
			@types == other.types && @primitives == other.primitives
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
		when Literal::Types::UnionType
			other.types.all? { |type| covers?(type, context:) } &&
				other.primitives.all? { |primitive| covers?(primitive, context:) }
		when Literal::Types::TaggedUnionType
			other.members.values.all? { |type| covers?(type, context:) }
		when Literal::Types::NilableType
			covers?(nil, context:) && covers?(other.type, context:)
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

	private def primitive_match?(value)
		@primitives.include?(value)
	rescue ::StandardError
		@primitives.any? { |primitive| primitive == value }
	end

	def <=(other, context: nil)
		@primitives.all? { |primitive| Literal.subtype?(primitive, other, context:) } &&
			@types.all? { |type| Literal.subtype?(type, other, context:) }
	end

	freeze
end
