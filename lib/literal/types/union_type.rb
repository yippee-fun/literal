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

	def inspect
		"_Union(#{to_a.map(&:inspect).join(', ')})"
	end

	def ===(value)
		return true if @primitives.include?(value)

		types = @types

		i, len = 0, types.size
		while i < len
			return true if types[i] === value
			i += 1
		end

		false
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

	def [](key)
		if @primitives.include?(key) || @types.include?(key)
			key
		end
	end

	def fetch(key)
		self[key] or raise KeyError.new("Key not found: #{key.inspect}")
	end

	def >=(other)
		types = @types
		primitives = @primitives

		case other
		when Literal::Types::UnionType
			other.types.all? { |t| primitives.any? { |p| Literal.subtype?(t, p) } || types.any? { |t2| Literal.subtype?(t, t2) } } &&
				other.primitives.all? { |p| primitives.any? { |p2| Literal.subtype?(p, p2) } || types.any? { |t| Literal.subtype?(p, t) } }
		when Literal::Types::TaggedUnionType
			other.members.values.all? { |t| primitives.any? { |p| Literal.subtype?(t, p) } || types.any? { |t2| Literal.subtype?(t, t2) } }
		else
			primitives.any? { |p| Literal.subtype?(other, p) } || types.any? { |t| Literal.subtype?(other, t) }
		end
	end

	def <=(other)
		case other
		when Module
			@primitives.all? { |primitive| Literal.subtype?(primitive, other) } &&
				@types.all? { |type| Literal.subtype?(type, other) }
		end
	end

	freeze
end
