# frozen_string_literal: true

# Like _Void's, this kind must not match values itself: frozen values are
# matched by the kinds of their thawed types.
class Literal::Serializer::FrozenType
	include Literal::Serializer::Kind

	def initialize(context)
		@context = context
		freeze
	end

	def inspect
		"SerializableFrozen"
	end

	def ===(_value)
		false
	end

	def matches?(other)
		case other
		when Literal::Types::FrozenType
			true
		when Literal::Types::ConstraintType
			Literal.subtype?(other.property_constraints[:frozen?], true) ||
				other.object_constraints.any?(Literal::Types::FrozenType)
		else
			false
		end
	end
end

# Being frozen is representation, not data, so a type requiring frozen values
# serializes as its thawed type, and loaded values are frozen afterwards.
class Literal::FrozenSerializer < Literal::Serializer
	def initialize(context)
		@context = context
		@type = Literal::Serializer::FrozenType.new(@context)
	end

	attr_reader :type

	def handles_type?(type)
		@type.matches?(type) && @context.serializer_for?(thawed(type))
	end

	def rejection_reason(type)
		if @type.matches?(type) && !handles_type?(type)
			"there is no serializer for #{thawed(type).inspect}"
		end
	end

	def child_types(type)
		thawed_serializer(type).child_types(thawed(type))
	end

	def referenceable?(type)
		thawed_serializer(type).referenceable?(thawed(type))
	end

	def json_type(type)
		thawed_serializer(type).json_type(thawed(type))
	end

	def object_shape(type)
		thawed_serializer(type).object_shape(thawed(type))
	end

	def mergeable_object?(type)
		thawed_serializer(type).mergeable_object?(thawed(type))
	end

	def json_schema(type, generator: nil)
		thawed_serializer(type).json_schema(thawed(type), generator:)
	end

	def serialize(value, type:)
		thawed_serializer(type).serialize(value, type: thawed(type))
	end

	def deserialize(raw, type:)
		serializer = thawed_serializer(type)

		Literal::Freezing.deep_frozen(
			serializer.deserialize(serializer.coerce(raw), type: thawed(type)),
		)
	end

	private def thawed_serializer(type)
		@context.serializer_for_type(thawed(type))
	end

	private def thawed(type)
		thawed = unfrozen(type)
		thawed = thawed.materialize if Literal::Types::DeferredType === thawed

		thaws_to_nothing?(thawed) ? Literal::Types::NeverType::Instance : thawed
	end

	# A chain of frozen types and deferred aliases that leads back into
	# itself, like t = _Deferred { _Frozen(t) }, has no values.
	private def thaws_to_nothing?(type)
		seen = nil

		while Literal::Types::DeferredType === type || @type.matches?(type)
			seen ||= {}.compare_by_identity
			return true if seen.key?(type)

			seen[type] = true
			type = (Literal::Types::DeferredType === type) ? type.materialize : unfrozen(type)
		end

		false
	end

	# The type without its frozen requirement.
	private def unfrozen(type)
		case type
		when Literal::Types::FrozenType
			type.type
		when Literal::Types::ConstraintType
			object_constraints = type.object_constraints.map do |constraint|
				(Literal::Types::FrozenType === constraint) ? constraint.type : constraint
			end.uniq

			property_constraints = type.property_constraints.except(:frozen?)

			if object_constraints.size == 1 && property_constraints.empty?
				object_constraints.first
			else
				Literal::Types::ConstraintType.new(object_constraints, property_constraints)
			end
		end
	end
end
