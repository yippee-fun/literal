# frozen_string_literal: true

# A mutable Literal::Struct with optional (prop?-style) versions of another
# class's properties, for building up a value incrementally. Unset properties
# hold Literal::Undefined, so an explicit nil is distinguishable from "not
# provided yet". Create a draft class with `Literal::Draft(SomeType)`.
class Literal::Draft < Literal::Struct
	class << self
		# Generated draft classes override this with the class they draft.
		def __type__
			nil
		end

		# Draft classes are types: any draft of a subtype of our drafted type
		# matches, regardless of which Literal::Draft() call built its class.
		def ===(value)
			if __type__ && Literal::Draft === value
				Literal.subtype?(value.class.__type__, __type__)
			else
				super
			end
		end

		def >=(other, context: nil)
			my_type = __type__
			other_type = (Class === other && other < Literal::Draft) ? other.__type__ : nil

			if my_type && other_type
				Literal.subtype?(other_type, my_type, context:)
			else
				super(other)
			end
		end

		def <=(other, context: nil)
			my_type = __type__
			other_type = (Class === other && other < Literal::Draft) ? other.__type__ : nil

			if my_type && other_type
				Literal.subtype?(my_type, other_type, context:)
			else
				super(other)
			end
		end

		private def __draft__(type)
			unless Literal::Properties === type
				raise Literal::ArgumentError.new("Literal::Draft requires a class that extends Literal::Properties.")
			end

			define_singleton_method(:__type__) { type }

			if type.name && respond_to?(:set_temporary_name)
				set_temporary_name "Literal::Draft(#{type.name})"
			end

			type.literal_properties.each do |property|
				__draft_property__(property)
			end
		end

		private def __draft_property__(property)
			original_coercion = property.coercion

			prop(
				property.name,
				# Undefined first: union members are tried in order, and matching
				# the unset sentinel by identity keeps deferred types in the
				# relaxed member from materializing before a real value arrives.
				Literal::Types._Union(Literal::Undefined, __relax__(property.type)),
				property.kind,
				predicate: property.predicate,
				default: Literal::Undefined,
				description: property.description,
				&(original_coercion && proc { |value|
					# Coercions normalize input for the drafted type. Unset slots and
					# nested drafts aren't that input yet — the draft meets the
					# coercion's output contract at finalize, through its own
					# construction — so both pass through untouched.
					if Literal::Undefined == value || Literal::Draft === value
						value
					else
						instance_exec(value, &original_coercion)
					end
				})
			)
		end

		# Drafts relax the drafted type's requirements while a value is being
		# built up: representation — a _Frozen constraint doesn't bind draft
		# state — and finality — a slot typed as a Literal::Properties class
		# also accepts a draft of it. Finalizing re-imposes both through the
		# drafted type's own construction.
		private def __relax__(type)
			case type
			when Literal::Types::DeferredType
				# Wrapped rather than materialized: the deferred constant may not
				# be defined yet at draft-definition time.
				Literal::Types::DeferredType.new { __relax__(type.materialize) }
			when Literal::Types::FrozenType
				__relax__(type.type)
			when Literal::Types::NilableType
				Literal::Types._Nilable(__relax__(type.type))
			when Literal::Types::UnionType
				Literal::Types._Union(*type.types.map { |member| __relax__(member) }, *type.primitives)
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
	end

	# Matches any draft whose drafted type is a subtype of the given type —
	# what `Literal::Draft(type).===` matches, without generating a draft
	# class. Relaxed draft slots use this as their union member, which keeps
	# recursive types (a Person with a Person property) from recursing forever
	# at draft-class definition.
	class Type
		include Literal::Type

		def initialize(type)
			@type = type
			freeze
		end

		attr_reader :type

		def inspect
			"Literal::Draft(#{@type.inspect})"
		end

		def ===(value)
			Literal::Draft === value && (drafted = value.class.__type__) &&
				Literal.subtype?(drafted, @type)
		end

		def >=(other, context: nil)
			case other
			when Literal::Draft::Type
				Literal.subtype?(other.type, @type, context:)
			when Class
				if other <= Literal::Draft && (drafted = other.__type__)
					Literal.subtype?(drafted, @type, context:)
				else
					false
				end
			else
				false
			end
		end

		freeze
	end

	# Build the drafted type from the properties that have been set. The
	# drafted type's defaults apply to anything left unset, and its required
	# properties are enforced here. Any properties passed here are assigned
	# to the draft first — through its writers, so they're coerced and type
	# checked like any other assignment.
	#
	# Nested drafts finalize too, depth-first — unless the drafted type's
	# property accepts the draft as-is, in which case the slot wanted a draft
	# and it stays one. The draft itself is never mutated: finalizing twice
	# builds two independent values.
	def finalize(**props)
		type = self.class.__type__

		unless type.respond_to?(:from_props)
			raise Literal::ArgumentError.new("Cannot finalize a draft into #{type}, because it doesn't support from_props.")
		end

		props.each { |name, value| self[name] = value }

		properties = type.literal_properties
		attributes = {}

		to_h.each do |name, value|
			next if Literal::Undefined == value

			if Literal::Draft === value && !(properties[name].type === value)
				value = value.finalize
			end

			attributes[name] = value
		end

		type.from_props(attributes)
	end
end
