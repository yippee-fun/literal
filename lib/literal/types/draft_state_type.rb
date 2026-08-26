# frozen_string_literal: true

# @api private
#
# Matches what a slot typed as the given type may hold while drafting — the
# type with its requirements relaxed: representation (a `_Frozen` constraint
# doesn't bind draft state) and finality (a slot typed as a
# `Literal::Properties` class also accepts a draft of it). Finalizing a draft
# re-imposes both through the drafted type's own construction.
#
# The unset sentinel is not included: draft properties compose this with
# `Literal::Undefined` in a union, where its exact containment marks the
# property as omittable.
class Literal::Types::DraftStateType
	include Literal::Type

	def initialize(type)
		@type = type
		@relaxed = __relax__(type)
		freeze
	end

	attr_reader :type

	def literal_child_types
		return enum_for(__method__) unless block_given?

		yield @type
	end

	def inspect
		"_DraftState(#{@type.inspect})"
	end

	def ===(value)
		@relaxed === value
	end

	def record_literal_type_errors(ctx)
		@relaxed.record_literal_type_errors(ctx) if @relaxed.respond_to?(:record_literal_type_errors)
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::DraftStateType
			Literal.subtype?(other.__relaxed__, @relaxed, context:)
		else
			Literal.subtype?(other, @relaxed, context:)
		end
	end

	protected def __relaxed__
		@relaxed
	end

	private def __relax__(type)
		case type
		when Literal::Types::DraftTransparent
			# Each wrapper rebuilds itself around its relaxed children, so this
			# walk and everything that must agree with it — see the module — share
			# one definition of what a draft sees through.
			type.__relax__ { |child| __relax__(child) }
		when Literal::Properties
			# A slot typed as a draft class already holds draft state; only
			# final types get widened.
			if Class === type && type <= Literal::Draft
				type
			else
				Literal::Types._Union(type, Literal::Draft::Type.new(type))
			end
		else
			type
		end
	end

	freeze
end
