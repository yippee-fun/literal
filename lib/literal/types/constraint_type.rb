# frozen_string_literal: true

# @api private
class Literal::Types::ConstraintType
	include Literal::Type

	def initialize(object_constraints, property_constraints)
		@object_constraints = object_constraints
		@property_constraints = property_constraints
		freeze
	end

	attr_reader :object_constraints
	attr_reader :property_constraints

	def literal_child_types
		return enum_for(__method__) unless block_given?

		@object_constraints.each { |type| yield type }
		@property_constraints.each_value { |type| yield type }
	end

	def inspect
		"_Constraint(#{inspect_constraints})"
	end

	def ===(value)
		object_constraints = @object_constraints

		i, len = 0, object_constraints.size
		while i < len
			return false unless object_constraints[i] === value
			i += 1
		end

		result = true

		@property_constraints.each do |a, t|
			# We intentionally don’t return early here becuase it triggers an allocation.
			if result && !(t === value.public_send(a))
				result = false
				break
			end
		rescue NoMethodError => e
			raise unless e.name == a && e.receiver == value
			return false
		end

		result
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::ConstraintType
			other_object_constraints = other.object_constraints
			return false unless @object_constraints.all? do |constraint|
				other_object_constraints.any? { |c| Literal.subtype?(c, constraint, context:) }
			end

			other_property_constraints = other.property_constraints
			return false unless @property_constraints.all? do |k, v|
				Literal.subtype?(other_property_constraints[k], v, context:) ||
					other_object_constraints.any? { |constraint| constraint_property_subtype?(constraint, k, v, context:) } ||
					boolean_predicate_subtype?(other, k, v, context:)
			end

			true
		when Literal::Types::InterfaceType
			return false unless @property_constraints.empty?

			@object_constraints.all? { |constraint| Literal.subtype?(other, constraint, context:) }
		when Literal::Types::FrozenType
			# The only property _Frozen can vouch for is frozen?.
			@property_constraints.all? { |property, type| :frozen? == property && Literal.subtype?(true, type, context:) } &&
				@object_constraints.all? { |constraint| Literal.subtype?(other.type, constraint, context:) }
		when Literal::Types::UnionType
			other.<=(self, context:)
		when Module
			return false unless @property_constraints.empty?

			@object_constraints.all? { |constraint| Literal.subtype?(other, constraint, context:) }
		else
			literal_value?(other) && self === other
		end
	end

	def <=(other, context: nil)
		@object_constraints.any? { |constraint| Literal.subtype?(constraint, other, context:) } ||
			@property_constraints.any? { |property, type| property_entails_type?(property, type, other, context:) }
	end

	def record_literal_type_errors(context)
		@object_constraints.each do |constraint|
			next if constraint === context.actual

			context.add_child(label: inspect, expected: constraint, actual: context.actual)
		end

		@property_constraints.each do |property, constraint|
			next unless context.actual.respond_to?(property)
			actual = context.actual.public_send(property)
			next if constraint === actual

			context.add_child(label: ".#{property}", expected: constraint, actual:)
		end
	end

	private def inspect_constraints
		[inspect_object_constraints, inspect_property_constraints].compact.join(", ")
	end

	private def inspect_object_constraints
		if @object_constraints.length > 0
			@object_constraints.map(&:inspect).join(", ")
		end
	end

	private def inspect_property_constraints
		if @property_constraints.length > 0
			@property_constraints.map { |k, t| "#{k}: #{t.inspect}" }.join(", ")
		end
	end

	# Some property constraints prove class membership: any Numeric where
	# integer? is truthy is an Integer, so _Constraint(10, integer?: _Truthy)
	# <= Integer. The constraint must admit only truthy values and the
	# receiver must be bounded by the fact's receiver, or it proves nothing.
	private def property_entails_type?(property, type, other, context:)
		facts = Literal::Types::PredicateFacts[property]
		return false unless facts
		return false unless Literal.subtype?(type, Literal::Types::TruthyType::Instance, context:)

		facts.any? do |receiver, knowledge|
			(entailed = knowledge[:entails]) &&
				@object_constraints.any? { |constraint| Literal.subtype?(constraint, receiver, context:) } &&
				Literal.subtype?(entailed, other, context:)
		end
	end

	# A predicate known to return only booleans can only produce the booleans
	# the other constraint admits, so the requirement reduces to admitting
	# each of those.
	private def boolean_predicate_subtype?(other, property, type, context:)
		facts = Literal::Types::PredicateFacts[property]
		return false unless facts

		other_type = other.property_constraints[property]
		return false unless other_type

		return false unless facts.any? do |receiver, knowledge|
			knowledge[:boolean] &&
				other.object_constraints.any? { |constraint| Literal.subtype?(constraint, receiver, context:) }
		end

		[true, false].all? { |result| !(other_type === result) || type === result }
	end

	# A bounded Range proves finite? returns exactly true, satisfying any
	# property constraint that admits true.
	private def constraint_property_subtype?(constraint, property, type, context:)
		case [constraint, property]
		in [Range, :finite?]
			finite_range?(constraint) && Literal.subtype?(true, type, context:)
		else
			false
		end
	end

	private def finite_range?(range)
		range.begin && range.end &&
			(!Numeric === range.begin || range.begin.finite?) &&
			(!Numeric === range.end || range.end.finite?)
	end

	private def literal_value?(value)
		case value
		when Array, Hash, String, Symbol, Integer, Float, Complex, Rational, true, false, nil
			true
		else
			!!(defined?(::BigDecimal) && ::BigDecimal === value)
		end
	end

	freeze
end
