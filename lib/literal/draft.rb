# frozen_string_literal: true

# A mutable Literal::Struct with optional (prop?-style) versions of another
# class's properties, for building up a value incrementally. Unset properties
# hold Literal::Undefined, so an explicit nil is distinguishable from "not
# provided yet". Create a draft class with `Literal::Draft(SomeType)`.
class Literal::Draft < Literal::Struct
	# Draft classes keyed by the drafted class's schema — see Literal.Draft.
	# The schema, not its snapshot: WeakKeyMap compares keys with eql?, and a
	# subclass's snapshot is eql? to its parent's, while schemas are one per
	# class and compare by identity. Each entry holds [snapshot, draft] so a
	# schema change (snapshot identity change) reads as a miss. The key is
	# weak: when a class is collected, its schema and cached draft follow.
	CACHE = ObjectSpace::WeakKeyMap.new

	class << self
		# Generated draft classes override this with the class they draft.
		def __type__
			nil
		end

		# Build a finalized value in one call: constructs a draft (passing any
		# arguments through), yields it to the block, and finalizes it.
		def build(*, **, &)
			new(*, **).finalize(&)
		end

		# The soft path for a Hash of props from outside, keyed by Symbol or
		# String, where nothing may raise: every error is reported, type errors
		# included, and a Literal::Result carries the built value or the errors.
		# A draft's own writers type check, so for props already in hand build
		# the draft and ask it: `Literal::Draft(Shape).new(...).check`.
		def check(props)
			unless Hash === props
				raise Literal::ArgumentError.new(
					"#{name || inspect}.check takes a Hash of properties, got #{props.class}"
				)
			end

			Literal::Checks::Checker.check(__checked_type__, props)
		end

		def __checked_type__
			__type__ || raise(Literal::ArgumentError.new("Cannot check an untyped draft."))
		end

		# A draft holds its type's checks in abeyance, so it declares none of its
		# own. (`check` is the soft path above, not the declaration.)
		def checks(&)
			raise Literal::ArgumentError.new(
				"Cannot declare checks on a draft; declare them on #{__type__ || 'the drafted type'}."
			)
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
			if property.const?
				return const(property.name, property.default, description: property.description)
			end

			original_coercion = property.coercion

			prop(
				property.name,
				# Undefined first: union members are tried in order, and matching
				# the unset sentinel by identity keeps deferred types in the
				# relaxed member from materializing before a real value arrives.
				Literal::Types._Union(Literal::Undefined, Literal::Types._DraftState(property.type)),
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
						__context__.instance_exec(value, &original_coercion)
					end
				})
			)
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
	# and it stays one. The draft itself is never mutated by building: aside
	# from any props and block given here, finalizing twice builds two
	# independent values.
	#
	# A block receives the draft after any props are assigned and before the
	# value is built — for last touches like conditional assignment.
	def finalize(**props, &)
		self.class.__type__.from_props(__finalize_attributes__(props, &))
	end

	# Finalize without enforcing the drafted type's checks or sealing again, for
	# the checker, which has already done both against this draft. Private,
	# or any caller could turn a failing draft into a value that breaks its
	# shape's checks.
	private def __finalize_unchecked__
		type = self.class.__type__
		type.__send__(:__literal_from_props__, __finalize_attributes__({}), seal: false)
	end

	private def __finalize_attributes__(props)
		type = self.class.__type__

		unless type.respond_to?(:from_props)
			raise Literal::ArgumentError.new("Cannot finalize a draft into #{type}, because it doesn't support from_props.")
		end

		props.each { |name, value| self[name] = value }

		yield self if block_given?

		properties = type.literal_properties
		attributes = {}

		to_h.each do |name, value|
			next if Literal::Undefined == value

			if Literal::Draft === value && !(properties[name].type === value)
				value = value.finalize
			end

			attributes[name] = value
		end

		attributes
	end

	# Answers a Literal::Result carrying the built value or every error found:
	# the type errors and, once the types hold, the shape's checks. The draft
	# itself is never mutated.
	def check
		Literal::Checks::Checker.check(self.class.__checked_type__, self)
	end

	def sound?
		check.success?
	end

	# For the checker, which has already coerced the value and checked it
	# against the prop's real type, and must not do either twice.
	def __store__(name, value)
		property = self.class.literal_properties[name] ||
			raise(NameError.new("unknown attribute: #{name.inspect} for #{self.class}"))

		instance_variable_set(property.__ivar__, value)
	end

	# A copy gets its own context: the memoized receiver below belongs to one
	# draft, or checking the copy would write onto an object the original
	# can still reach.
	private def initialize_copy(source)
		super
		remove_instance_variable(:@__context__) if instance_variable_defined?(:@__context__)
	end

	# Coercions and defaults are written for the drafted type — they may call
	# its own methods and read the properties assigned before them, exactly as
	# they do in the generated initializer. So they run against an instance of
	# the drafted type carrying the draft's values as they stand, synced on
	# each use. One instance per draft, shared with the checker.
	def __context__
		context = (@__context__ ||= self.class.__type__.allocate)

		self.class.__type__.literal_properties.each do |property|
			value = instance_variable_get(property.__ivar__)

			if Literal::Undefined == value
				# An unset slot reads as unset — including one set and then reset,
				# whose earlier sync must not linger.
				if context.instance_variable_defined?(property.__ivar__)
					context.remove_instance_variable(property.__ivar__)
				end
			else
				context.instance_variable_set(property.__ivar__, value)
			end
		end

		context
	end
end
