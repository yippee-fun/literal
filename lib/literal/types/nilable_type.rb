# frozen_string_literal: true

# @api private
class Literal::Types::NilableType
	include Literal::Type
	include Literal::Types::DraftTransparent

	def initialize(type)
		@type = type
		@hash = literal_hash(Literal::Types::NilableType, type)
		freeze
	end

	attr_reader :type, :hash

	def ==(other)
		Literal::Types::NilableType === other && @type == other.type
	end

	def eql?(other)
		Literal::Types::NilableType === other && @type.eql?(other.type)
	end

	def __relax__
		Literal::Types._Nilable(yield(@type))
	end

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_Nilable(#{@type.inspect})"
	end

	def literal_upper_bound
		Literal::Types._Union(NilClass, @type)
	end

	def ===(value)
		nil === value || !!(@type === value)
	end

	def record_literal_type_errors(ctx)
		@type.record_literal_type_errors(ctx) if @type.respond_to?(:record_literal_type_errors)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::VoidType
			@type == Literal::Types::AnyType::Instance
		when Literal::Types::NilableType
			Literal.subtype?(other.type, @type, context:)
		when Literal::Types::UnionType
			# nil is covered by definition, so only the other members need to be.
			# Without this, `_Union(String, nil)` is not recognised as a subtype of
			# `_Nilable(String)`, even though the two denote the same set.
			other.all? { |member| nil == member || Literal.subtype?(member, @type, context:) }
		when nil
			true
		else
			Literal.subtype?(other, @type, context:)
		end
	end

	freeze
end
