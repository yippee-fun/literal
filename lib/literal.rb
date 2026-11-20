# frozen_string_literal: true

require "zeitwerk"
require_relative "literal/version"

module Literal
	# An instance method held for calling with bind_call, shareable so any
	# Ractor can use it on Rubies that can share method objects (4.0+).
	def self.method_handle(owner, name)
		handle = owner.instance_method(name)
		Ractor.make_shareable(handle) if defined?(Ractor)
		handle
	rescue Ractor::Error
		handle
	end

	OBJECT_ID = method_handle(BasicObject, :__id__)
	EQUAL = method_handle(BasicObject, :equal?)
	FROZEN = method_handle(Kernel, :frozen?)
	FREEZE = method_handle(Kernel, :freeze)
	CLASS = method_handle(Kernel, :class)
	SEND = method_handle(BasicObject, :__send__)
	PUBLIC_SEND = method_handle(Kernel, :public_send)
	INSTANCE_EXEC = method_handle(BasicObject, :instance_exec)
	RESPOND_TO = method_handle(Kernel, :respond_to?)
	DUP = method_handle(Kernel, :dup)
	INSTANCE_VARIABLE_GET = method_handle(Kernel, :instance_variable_get)
	INSTANCE_VARIABLE_SET = method_handle(Kernel, :instance_variable_set)
	INSTANCE_VARIABLE_DEFINED = method_handle(Kernel, :instance_variable_defined?)
	REMOVE_INSTANCE_VARIABLE = method_handle(Kernel, :remove_instance_variable)
	METHOD = method_handle(Kernel, :method)
	HASH = method_handle(Kernel, :hash)
	INSPECT = method_handle(Kernel, :inspect)

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

	SINGLETON_METHODS = method_handle(Kernel, :singleton_methods)

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

	# Compares and hashes a type's members, which may be matchers without eql?
	# or hash, like a BasicObject: those compare by identity. A container met
	# again is met through a cycle, and answers true or 0, as Ruby's recursive
	# eql? and hash do.
	def self.member_eql?(member, other, active = nil)
		member.eql?(other)
	rescue NoMethodError
		case member
		when ::Array, ::Hash
			active ||= {}.compare_by_identity
			return true if active.key?(member)

			active[member] = true

			begin
				case member
				when ::Array
					::Array === other && member.size == other.size && member.each_index.all? { |i| member_eql?(member[i], other[i], active) }
				else
					::Hash === other && member.size == other.size && member.all? { |key, item| other.key?(key) && member_eql?(item, other[key], active) }
				end
			ensure
				active.delete(member)
			end
		else
			payload_eql?(member, other)
		end
	end

	def self.member_hash(member, active = nil)
		member.hash
	rescue NoMethodError
		case member
		when ::Array, ::Hash
			active ||= {}.compare_by_identity
			return 0 if active.key?(member)

			active[member] = true

			begin
				case member
				when ::Array
					member.map { |item| member_hash(item, active) }.hash
				else
					member.to_h { |key, item| [member_hash(key, active), member_hash(item, active)] }.hash
				end
			ensure
				active.delete(member)
			end
		else
			payload_hash(member)
		end
	end

	def self.const_name(object)
		const_ref(object).first&.name
	end

	def self.const_ref(object)
		ConstantTracker.const_ref(object)
	end

	# Readies a shape to be built and read in any Ractor. It is frozen, the
	# deferred types its properties reach are materialized, and its schema and
	# checks are deeply frozen — defaults, coercions and check blocks too, so
	# none of them may capture mutable state.
	def self.make_shareable(shape)
		unless Literal::Properties === shape
			raise Literal::ArgumentError.new("Literal.make_shareable requires a class that extends Literal::Properties.")
		end

		shape.freeze
		shape.__send__(:__literal_make_shareable__)
		shape
	end

	def self.main_ractor?
		!defined?(Ractor) || Ractor.current.equal?(Ractor.main)
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

		# With no Literal type on either side, only a context could bring the
		# check back to this pair, so a check that starts here needs none.
		if context.nil? && !(Literal::Type === type || Literal::Type === supertype)
			return !!resolved_subtype?(type, supertype, nil)
		end

		context ||= SubtypeContext.new
		type_id = OBJECT_ID.bind_call(type)
		supertype_id = OBJECT_ID.bind_call(supertype)

		# Coinductive cycle handling: if we are already in the middle of proving this
		# exact pair, assume it holds — provided the cycle justifies it (see
		# SubtypeContext#assume). This is what makes subtyping between recursive
		# (looping) types terminate with the right answer.
		known = context.recall(type_id, supertype_id, type)
		return known unless known.nil?

		raw_frame = context.acquire(type_id, supertype_id)
		subtype = type
		resolved_supertype = supertype

		if Types::DeferredType === type || Types::DeferredType === supertype
			subtype = context.unfold_left(type) if Types::DeferredType === type
			resolved_supertype = supertype.materialize if Types::DeferredType === supertype
			subtype_id = OBJECT_ID.bind_call(subtype)
			resolved_supertype_id = OBJECT_ID.bind_call(resolved_supertype)

			unless subtype_id == type_id && resolved_supertype_id == supertype_id
				known = context.recall(subtype_id, resolved_supertype_id, subtype)

				unless known.nil?
					context.store(type_id, supertype_id, raw_frame, known)
					return known
				end

				resolved_frame = context.acquire(subtype_id, resolved_supertype_id)
			end
		end

		result = !!resolved_subtype?(subtype, resolved_supertype, context)

		# A proof resting on an assumption its type turned out not to support
		# stores nothing, and is tried again refusing that assumption.
		while context.store(type_id, supertype_id, raw_frame, result).nil?
			result = !!resolved_subtype?(subtype, resolved_supertype, context)
		end

		context.store(subtype_id, resolved_supertype_id, resolved_frame, result) if resolved_frame
		result
	ensure
		context.release(subtype_id, resolved_supertype_id, resolved_frame) if resolved_frame
		context.release(type_id, supertype_id, raw_frame) if raw_frame
	end

	# A union is a subtype of anything all its members are subtypes of.
	private_class_method def self.resolved_subtype?(subtype, supertype, context)
		return true if subtype == Types::NeverType::Instance || supertype == subtype

		case subtype
		in Types::DeferredType unless Types::DeferredType === supertype
			context.left_unfolded_subtype?(subtype, supertype)
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
				supertype.literal_supertype_of?(subtype, context:) ||
					(Literal::Type === subtype && subtype.literal_subtype_of?(supertype, context:)) ||
					bounded_subtype?(subtype, supertype, context)
			when Module
				case subtype
				when Module
					supertype >= subtype
				when Literal::Type
					subtype.literal_subtype_of?(supertype, context:)
				else
					bounded_subtype?(subtype, supertype, context)
				end
			when Range
				case subtype
				when Literal::Type
					subtype.literal_subtype_of?(supertype, context:)
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
		in [lower, other_lower]
			# <=> may answer any number, like a difference, so only its sign counts.
			case lower <=> other_lower
			in Numeric => order then order <= 0
			else false
			end
		end

		end_contained = case [range.end, other.end]
		in [nil, _] then true
		in [_, nil] then false
		in [upper, other_upper]
			case upper <=> other_upper
			in Numeric => order if order.zero? then !range.exclude_end? || other.exclude_end?
			in Numeric => order then order > 0
			else false
			end
		end

		begin_contained && end_contained
	end
end

Module.prepend(Literal::ConstantTracker)

require_relative "literal/railtie" if defined?(Rails)
