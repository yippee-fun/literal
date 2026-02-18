# frozen_string_literal: true

class Literal::Types::TaggedUnionType
	include Literal::Type

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
		freeze
	end

	attr_reader :members

	def inspect
		pairs = @members.map { |tag, type| "#{tag}: #{type.inspect}" }
		"_TaggedUnion(#{pairs.join(', ')})"
	end

	def ===(value)
		@members.each_value.any? { |type| type === value }
	end

	def [](tag)
		@members[tag]
	end

	def tag_for(value)
		@members.each { |tag, type| return tag if type === value }
		raise Literal::ArgumentError.new("No tag found for #{value.inspect} in #{inspect}.")
	end

	def type_of(value)
		@members.each_value { |type| return type if type === value }
		raise Literal::ArgumentError.new("No type found for #{value.inspect} in #{inspect}.")
	end

	def resolve(value)
		@members.each { |tag, type| return tag, type if type === value }
		raise Literal::ArgumentError.new("No match found for #{value.inspect} in #{inspect}.")
	end

	def >=(other)
		types = @members.values

		case other
		when Literal::Types::TaggedUnionType
			other.members.values.all? { |t| types.any? { |t2| Literal.subtype?(t, t2) } }
		when Literal::Types::UnionType
			other.types.all? { |t| types.any? { |t2| Literal.subtype?(t, t2) } } &&
				other.primitives.all? { |p| types.any? { |t| Literal.subtype?(p, t) } }
		else
			types.any? { |t| Literal.subtype?(other, t) }
		end
	end

	freeze
end
