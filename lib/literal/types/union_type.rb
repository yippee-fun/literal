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

	def each(&)
		@primitives.each(&)
		@types.each(&)
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
			types_have_at_least_one_subtype = other.types.all? do |other_type|
				primitives.any? { |p| Literal.subtype?(other_type, p) } || types.any? { |t| Literal.subtype?(other_type, t) }
			end

			primitives_have_at_least_one_subtype = other.primitives.all? do |other_primitive|
				primitives.any? { |p| Literal.subtype?(other_primitive, p) } || types.any? { |t| Literal.subtype?(other_primitive, t) }
			end

			types_have_at_least_one_subtype && primitives_have_at_least_one_subtype
		else
			types.any? { |t| Literal.subtype?(other, t) } || primitives.any? { |p| Literal.subtype?(other, p) }
		end
	end

	freeze
end
