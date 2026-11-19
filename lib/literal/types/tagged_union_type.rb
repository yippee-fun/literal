# frozen_string_literal: true

class Literal::Types::TaggedUnionType
	include Literal::Type
	include Literal::Types::Distributed

	def initialize(**members)
		raise Literal::ArgumentError.new("_TaggedUnion type must have at least one member.") if members.empty?

		flattened = {}
		members.each do |tag, type|
			if Literal::Types::TaggedUnionType === type
				type.members.each do |inner_tag, inner_type|
					raise Literal::ArgumentError.new("_TaggedUnion has duplicate tag: #{inner_tag.inspect}") if flattened.key?(inner_tag)
					flattened[inner_tag] = inner_type
				end
			else
				raise Literal::ArgumentError.new("_TaggedUnion has duplicate tag: #{tag.inspect}") if flattened.key?(tag)
				flattened[tag] = type
			end
		end

		@members = flattened.freeze
		@pairs = flattened.map(&:freeze).freeze
		primitive_pairs, type_pairs = @pairs.partition do |(_tag, type)|
			Literal::Types::UnionType::PRIMITIVES.any? { |primitive| primitive === type }
		end
		@primitive_pairs = primitive_pairs.uniq { |(_tag, type)| type }.to_h { |pair| [pair[1], pair] }.freeze
		@primitive_pair_list = @primitive_pairs.values.freeze
		@type_pairs = type_pairs.freeze
		@guarded = Literal::Types::UnionType.reaches_opaque_match?(flattened.each_value)
		@hash = literal_hash(Literal::Types::TaggedUnionType, @pairs)
		freeze
	end

	attr_reader :members, :hash

	protected attr_reader :pairs

	# Like UnionType: `==` ignores member order, `eql?` doesn't.
	def ==(other)
		Literal::Types::TaggedUnionType === other && @members == other.members
	end

	def eql?(other)
		Literal::Types::TaggedUnionType === other && @pairs.eql?(other.pairs)
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		@members.each_value { |type| yield type }
	end

	def inspect
		pairs = @members.map { |tag, type| "#{tag}: #{type.inspect}" }
		"_TaggedUnion(#{pairs.join(', ')})"
	end

	def ===(value)
		if @guarded
			Literal.with_match_guard(self, value) { member_match?(value) }
		else
			member_match?(value)
		end
	end

	# Literal members match with ==, as in a union, so === agrees with resolve.
	private def member_match?(value)
		!primitive_pair(value).nil? ||
			@type_pairs.any? { |(_tag, type)| type === value } ||
			!equal_primitive_pair(value).nil?
	end

	def [](tag)
		@members[tag]
	end

	def tag_for(value)
		tag, _type = member_for(value) || raise(Literal::ArgumentError.new("No tag found for #{value.inspect} in #{inspect}."))
		tag
	end

	def type_of(value)
		_tag, type = member_for(value) || raise(Literal::ArgumentError.new("No type found for #{value.inspect} in #{inspect}."))
		type
	end

	# The tag and type of a most specific matching member.
	def resolve(value)
		member_for(value) || raise(Literal::ArgumentError.new("No match found for #{value.inspect} in #{inspect}."))
	end

	# Like UnionType#resolve: a literal member the value is, or else a most
	# specific matching type, or else a literal the value is merely == to.
	private def member_for(value)
		pair = primitive_pair(value)
		return pair if pair

		pairs = @type_pairs

		i, len = 0, pairs.size
		while i < len
			pair = pairs[i]

			if pair[1] === value
				j = i + 1
				while j < len
					return most_specific_pair(i, j, value) if pairs[j][1] === value
					j += 1
				end

				return pair
			end

			i += 1
		end

		equal_primitive_pair(value)
	end

	private def primitive_pair(value)
		@primitive_pairs[value]
	rescue
		nil
	end

	private def equal_primitive_pair(value)
		pairs = @primitive_pair_list

		i, len = 0, pairs.size
		while i < len
			pair = pairs[i]
			return pair if pair[1] == value
			i += 1
		end

		nil
	end

	# Pairs `first` and `second` both match; no pair between them does.
	private def most_specific_pair(first, second, value)
		pairs = @type_pairs
		matches = [pairs[first], pairs[second], *pairs[(second + 1)..].select { |(_tag, type)| type === value }]
		Literal::Types::UnionType.most_specific(matches) { |(_tag, type)| type }
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::Distributed, Literal::Types::DeferredType
			Literal.subtype?(other, self, context:)
		else
			@members.each_value.any? { |type| Literal.subtype?(other, type, context:) }
		end
	end

	freeze
end
