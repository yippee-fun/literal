# frozen_string_literal: true

require "zeitwerk"
require_relative "literal/version"

module Literal
	OBJECT_ID = BasicObject.instance_method(:__id__)
	EQUAL = BasicObject.instance_method(:equal?)
	FROZEN = Kernel.instance_method(:frozen?)
	FREEZE = Kernel.instance_method(:freeze)
	CLASS = Kernel.instance_method(:class)
	SEND = BasicObject.instance_method(:__send__)
	PUBLIC_SEND = Kernel.instance_method(:public_send)
	INSTANCE_EXEC = BasicObject.instance_method(:instance_exec)
	RESPOND_TO = Kernel.instance_method(:respond_to?)
	DUP = Kernel.instance_method(:dup)
	INSTANCE_VARIABLE_GET = Kernel.instance_method(:instance_variable_get)
	INSTANCE_VARIABLE_SET = Kernel.instance_method(:instance_variable_set)
	INSTANCE_VARIABLE_DEFINED = Kernel.instance_method(:instance_variable_defined?)
	REMOVE_INSTANCE_VARIABLE = Kernel.instance_method(:remove_instance_variable)
	METHOD = Kernel.instance_method(:method)
	HASH = Kernel.instance_method(:hash)
	INSPECT = Kernel.instance_method(:inspect)

	Loader = Zeitwerk::Loader.for_gem.tap do |loader|
		loader.ignore("#{__dir__}/literal/kernel.rb")
		loader.ignore("#{__dir__}/literal/rails")
		loader.ignore("#{__dir__}/literal/railtie.rb")
		loader.ignore("#{__dir__}/ruby_lsp")

		loader.inflector.inflect(
			"json_data_serializer" => "JSONDataSerializer",
			"json_data_type" => "JSONDataType",
			"json_schema" => "JSONSchema",
			"json_schema_number_serializer" => "JSONSchemaNumberSerializer"
		)

		loader.collapse("#{__dir__}/literal/flags")
		loader.collapse("#{__dir__}/literal/errors")
		loader.collapse("#{__dir__}/literal/serializers")

		loader.setup
	end

	Immediate = Types._Union(Integer, Float, Symbol, nil, Types._Boolean)

	SINGLETON_METHODS = Kernel.instance_method(:singleton_methods)

	# Kernel#respond_to? needs respond_to_missing?, which BasicObject lacks on JRuby.
	def self.implements?(object, method_name)
		class_of_object = CLASS.bind_call(object)

		if class_of_object.private_method_defined?(:respond_to_missing?) || class_of_object.method_defined?(:respond_to_missing?)
			RESPOND_TO.bind_call(object, method_name, true)
		else
			class_of_object.private_method_defined?(method_name) || class_of_object.method_defined?(method_name) ||
				SINGLETON_METHODS.bind_call(object).include?(method_name)
		end
	end

	# Compares and hashes a wrapped payload, which may undefine eql? or hash,
	# or replace __send__.
	def self.payload_eql?(payload, other)
		EQUAL.bind_call(payload, other) || (implements?(payload, :eql?) && SEND.bind_call(payload, :eql?, other))
	end

	def self.payload_hash(payload)
		implements?(payload, :hash) ? SEND.bind_call(payload, :hash) : HASH.bind_call(payload)
	end

	def self.const_name(object)
		const_ref(object).first&.name
	end

	def self.const_ref(object)
		ConstantTracker.const_ref(object)
	end

	def self.Value(*, **, &block)
		value_class = Class.new(Literal::Value)

		type = Literal::Types._Constraint(*, **)
		value_class.define_method(:__type__) { type }

		if subtype?(type, Integer)
			value_class.alias_method :to_i, :value
		elsif subtype?(type, String)
			value_class.alias_method :to_s, :value
			value_class.alias_method :to_str, :value
		elsif subtype?(type, ::Array)
			value_class.alias_method :to_a, :value
			value_class.alias_method :to_ary, :value
		elsif subtype?(type, ::Hash)
			value_class.alias_method :to_h, :value
		elsif subtype?(type, Float)
			value_class.alias_method :to_f, :value
		elsif subtype?(type, ::Set)
			value_class.alias_method :to_set, :value
		end

		value_class.class_eval(&block) if block
		value_class.freeze
	end

	def self.Delegator(*, **, &block)
		delegator_class = Class.new(Literal::Delegator)

		type = Literal::Types._Constraint(*, **)
		delegator_class.define_method(:__type__) { type }

		delegator_class.class_eval(&block) if block
		delegator_class.freeze
	end

	def self.Enum(type)
		Class.new(Literal::Enum) do
			prop :value, type, :positional, reader: :public
		end
	end

	# Returns the canonical draft class for the given class at its current
	# shape: repeated calls return the same class until the drafted class's
	# properties change, at which point a fresh draft class is generated and
	# the stale one becomes collectable.
	def self.Draft(type)
		unless Literal::Properties === type
			raise Literal::ArgumentError.new("Literal::Draft requires a class that extends Literal::Properties.")
		end

		schema = type.literal_properties
		snapshot = schema.snapshot
		cached = Literal::Draft::CACHE[schema]

		if cached && snapshot.equal?(cached[0])
			cached[1]
		else
			draft = Class.new(Literal::Draft) do
				__draft__(type)
			end

			Literal::Draft::CACHE[schema] = [snapshot, draft].freeze

			draft
		end
	end

	def self.Coercion(&)
		Literal::Coercion.new(&)
	end

	def self.Seal(&)
		Literal::Seal.new(&)
	end

	def self.Array(type)
		Literal::Array::Generic.new(type)
	end

	def self.Set(type)
		Literal::Set::Generic.new(type)
	end

	def self.Hash(key_type, value_type)
		Literal::Hash::Generic.new(key_type, value_type)
	end

	def self.Tuple(*types)
		Literal::Tuple::Generic.new(*types)
	end

	def self.Brand(...)
		Literal::Brand.new(...)
	end

	def self.Result(success_type, failure_type, &)
		result_type = Result::Generic.new(success_type, failure_type)

		if block_given?
			result_type.try(&)
		else
			result_type
		end
	end

	def self.Success(type)
		Success::Generic.new(type)
	end

	def self.Failure(type)
		Failure::Generic.new(type)
	end

	def self.check(value, type)
		if type === value
			true
		else
			context = Literal::TypeError::Context.new(expected: type, actual: value)
			type.record_literal_type_errors(context) if type.respond_to?(:record_literal_type_errors)
			yield context if block_given?
			raise Literal::TypeError.new(context:)
		end
	end

	# The guard is a flat stack of [type, value] pairs, kept between calls so a
	# warm check doesn't allocate. It only ever holds the current descent, so
	# scanning it is cheap.
	def self.with_match_guard(type, value)
		stack = (Thread.current[:literal_match_stack] ||= [])

		i = 0
		size = stack.size
		while i < size
			return false if EQUAL.bind_call(stack[i], type) && EQUAL.bind_call(stack[i + 1], value)
			i += 2
		end

		stack.push(type, value)

		begin
			yield
		ensure
			stack.pop
			stack.pop
		end
	end

	# Like subtype?, but marks the check as descending into a component of a
	# structural constructor (array element, hash key/value, tuple slot, etc.),
	# which licenses coinductive assumptions on recursive types.
	def self.structural_subtype?(type, supertype, context: nil)
		context ||= SubtypeContext.new
		context.structural { subtype?(type, supertype, context:) }
	end

	def self.subtype?(type, supertype, context: nil)
		return !!(supertype >= type) if Module === type && Module === supertype && !(Literal::Type === supertype)

		context ||= SubtypeContext.new
		raw_key = [OBJECT_ID.bind_call(type), OBJECT_ID.bind_call(supertype)]
		raw_acquired = false
		resolved_key = nil
		resolved_acquired = false

		return context.fetch(raw_key) if context.memoized?(raw_key)

		# Coinductive cycle handling: if we are already in the middle of proving this
		# exact pair, assume it holds — provided the recursion has passed through a
		# structural constructor (see SubtypeContext#assume). This is what makes
		# subtyping between recursive (looping) types terminate with the right answer.
		return context.assume(raw_key) unless context.acquire(raw_key)

		raw_acquired = true

		subtype = type

		subtype = subtype.materialize if Types::DeferredType === subtype
		supertype = supertype.materialize if Types::DeferredType === supertype
		resolved_key = [OBJECT_ID.bind_call(subtype), OBJECT_ID.bind_call(supertype)]

		if resolved_key != raw_key
			if context.memoized?(resolved_key)
				result = context.fetch(resolved_key)
				context.store(raw_key, result)
				return result
			end

			return context.assume(resolved_key) unless context.acquire(resolved_key)

			resolved_acquired = true
		end

		result = !!resolved_subtype?(subtype, supertype, context)

		context.store(resolved_key, result)
		context.store(raw_key, result)
		result
	ensure
		if context
			context.release(resolved_key) if resolved_acquired
			context.release(raw_key) if raw_acquired
		end
	end

	# A union is a subtype of anything all its members are subtypes of.
	private_class_method def self.resolved_subtype?(subtype, supertype, context)
		return true if subtype == Types::NeverType::Instance || supertype == subtype

		case subtype
		in Types::UnionType
			subtype.all? { |member| subtype?(member, supertype, context:) }
		in Types::NilableType
			subtype?(nil, supertype, context:) && subtype?(subtype.type, supertype, context:)
		in Types::TaggedUnionType
			subtype.members.each_value.all? { |member| subtype?(member, supertype, context:) }
		in Result::Generic
			# Results are closed: Result(S, F) is _Union(Success(S), Failure(F)).
			subtype?(Success(subtype.success_type), supertype, context:) &&
				subtype?(Failure(subtype.failure_type), supertype, context:)
		else
			member_subtype?(subtype, supertype, context)
		end
	end

	# The tightest type closed under a literal's ==, which bounds every value
	# the literal admits as a type. Numeric equality crosses classes
	# (10 == 10.0 == 10r == Complex(10)), so a numeric literal is bounded by
	# the core numerics and its own class — use _Integer(10) for an
	# Integer-anchored one — and a Date equals any DateTime or number (its
	# astronomical Julian day) on the same instant. Like the rest of subtype?,
	# this is sound against honest core types: String#== and friends defer to
	# an operand that merely converts, like one responding to to_str.
	def self.literal_bound(literal)
		case literal
		in Numeric then numerics_or(literal.class)
		in String then String
		in Symbol then Symbol
		in ::Array then ::Array
		in ::Hash then ::Hash
		in nil | true | false then literal.class
		else
			numerics_or(::Date) if defined?(::Date) && ::Date === literal
		end
	end

	private_class_method def self.numerics_or(type)
		Types._Union(Integer, Float, Rational, Complex, *(::BigDecimal if defined?(::BigDecimal)), type)
	end

	# A literal is a subtype of whatever its bound is a subtype of.
	private_class_method def self.bounded_subtype?(literal, supertype, context)
		bound = literal_bound(literal)
		!bound.nil? && subtype?(bound, supertype, context:)
	end

	private_class_method def self.member_subtype?(subtype, supertype, context)
		if supertype == nil
			subtype == NilClass
		elsif supertype == true
			subtype == TrueClass
		elsif supertype == false
			subtype == FalseClass
		else
			case supertype
			when Literal::Type
				supertype.>=(subtype, context:) || bounded_subtype?(subtype, supertype, context)
			when Module
				case subtype
				when Module
					supertype >= subtype
				when Literal::Type
					subtype.<=(supertype, context:)
				else
					bounded_subtype?(subtype, supertype, context)
				end
			when Range
				case subtype
				when Literal::Type
					subtype.<=(supertype, context:)
				when Range
					range_contains?(supertype, subtype)
				else
					supertype.cover?(subtype)
				end
			else
				false
			end
		end
	end

	# Range#cover?(range) treats integer ranges as discrete, so (1..4) covers
	# (1...5) even though 4.5 is in the latter. Compare the endpoints instead.
	private_class_method def self.range_contains?(range, other)
		begin_contained = case [range.begin, other.begin]
		in [nil, _] then true
		in [_, nil] then false
		in [lower, other_lower] then (lower <=> other_lower) in -1 | 0
		end

		end_contained = case [range.end, other.end]
		in [nil, _] then true
		in [_, nil] then false
		in [upper, other_upper]
			case upper <=> other_upper
			in 1 then true
			in 0 then !range.exclude_end? || other.exclude_end?
			else false
			end
		end

		begin_contained && end_contained
	end
end

Module.prepend(Literal::ConstantTracker)

require_relative "literal/railtie" if defined?(Rails)
