# frozen_string_literal: true

# @api private
class Literal::Types::NilableType
	include Literal::Type
	include Literal::Types::DraftTransparent
	include Literal::Types::Distributed

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

	def ===(value)
		nil === value || !!(@type === value)
	end

	def record_literal_type_errors(ctx)
		@type.record_literal_type_errors(ctx) if @type.respond_to?(:record_literal_type_errors)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::Distributed, Literal::Types::DeferredType
			Literal.subtype?(other, self, context:)
		when Literal::Types::VoidType
			@type == Literal::Types::AnyType::Instance
		when nil
			true
		else
			Literal.subtype?(other, @type, context:)
		end
	end

	freeze
end
