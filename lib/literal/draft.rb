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
				Literal::Types._Union(property.type, Literal::Undefined),
				property.kind,
				predicate: property.predicate,
				default: Literal::Undefined,
				description: property.description,
				&(original_coercion && proc { |value|
					(Literal::Undefined == value) ? value : instance_exec(value, &original_coercion)
				})
			)
		end
	end

	# Build the drafted type from the properties that have been set. The
	# drafted type's defaults apply to anything left unset, and its required
	# properties are enforced here.
	def finalize
		type = self.class.__type__

		unless type.respond_to?(:from_props)
			raise Literal::ArgumentError.new("Cannot finalize a draft into #{type}, because it doesn't support from_props.")
		end

		type.from_props(to_h.reject { |_, value| Literal::Undefined == value })
	end
end
