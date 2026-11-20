# frozen_string_literal: true

# @api private
module Literal::Checks::Checker
	extend self

	# Its own object: any real value, Literal::Undefined included, is something
	# a coercion or a decode may legitimately return.
	REJECTED = Object.new.freeze
	private_constant :REJECTED

	# SystemStackError is not a StandardError, so an unbounded walk over cyclic
	# input would escape the boundary meant to catch bad input.
	MAX_DEPTH = 64
	private_constant :MAX_DEPTH

	NO_DUPLICATES = {}.freeze
	private_constant :NO_DUPLICATES

	JSON_DATA = Literal::Types._JSONData
	private_constant :JSON_DATA

	# Answers a Literal::Result carrying the built value or every error found.
	# `input` is a draft of the shape or a Hash of props from outside. With a
	# serialization context, `input` is serialized and comes from outside, so
	# anything but an object is reported, not raised.
	def check(shape, input, serialization_context: nil)
		shape = subject_shape(shape, input)

		unless shape.respond_to?(:from_props)
			raise Literal::ArgumentError.new(
				"#{shape.name || shape.inspect} cannot be checked, because it cannot be built from props"
			)
		end

		errors = Literal::Checks::Collector.new
		result_type = Literal::Result(shape, Literal::Checks::Errors)

		if serialization_context && !(Hash === input)
			errors.add(Literal::Checks::Message.for(shape, input))
			return result_type.failure(errors.to_errors)
		end

		draft, sound = run(shape, input, errors, 0, serialization_context)

		return result_type.failure(errors.to_errors) if !sound || errors.any?

		result_type.success(Literal::Draft::API::FINALIZE_UNCHECKED.bind_call(draft))
	end

	# `only` narrows to the checks whose outcome depends on one property — what
	# a writer needs, since the ones it cannot have affected held before the
	# write and hold after it.
	def run_checks(shape, errors, only: nil, &read)
		list = only ? shape.literal_checks_for(only) : shape.literal_checks

		# A tainted read failed the type pass, or holds a nested value that failed
		# its own checks and so is no value to hand on; a phantom read is a default
		# resolved while an unknown key went unmatched — possibly a typo of the
		# very prop that then defaulted. An unknown key makes defaults
		# untrustworthy, never the given values, so checks over those still run.
		# Chosen before any check runs: checks do not depend on one another, so
		# one failing holds no other back.
		runnable = list.reject do |check|
			check.reads.any? { |name| errors.tainted?(name) || errors.phantom?(name) }
		end

		runnable.each { |check| check.run(shape, errors, &read) }
	end

	# A draft of a subclass checks as its own class, so the errors and the
	# built value match what it is.
	private def subject_shape(shape, input)
		case input
		when Literal::Draft
			unless Literal::Draft(shape) === input
				drafted = Literal::CLASS.bind_call(input).__type__
				expected = shape.name || shape.inspect
				actual = drafted&.name || drafted&.inspect || "an untyped draft"

				raise Literal::ArgumentError.new(
					"Expected a draft of #{expected}, got a draft of #{actual}"
				)
			end

			Literal::CLASS.bind_call(input).__type__
		else
			shape
		end
	end

	private def run(shape, input, errors, depth, serialization_context)
		draft, sound = case input
		when Literal::Draft
			check_draft(shape, input, errors, depth)
		when Hash
			check_types(shape, input, errors, depth, serialization_context)
		else
			raise Literal::ArgumentError.new(
				"#{shape.name || shape.inspect} cannot check a #{input.class}; expected a Hash of properties or a draft of it"
			)
		end

		draft_properties = Literal::CLASS.bind_call(draft).literal_properties
		run_checks(shape, errors) do |name|
			ivar = draft_properties[name].__ivar__
			Literal::INSTANCE_VARIABLE_DEFINED.bind_call(draft, ivar) ? Literal::INSTANCE_VARIABLE_GET.bind_call(draft, ivar) : Literal::Undefined
		end

		[draft, sound]
	end

	# A value already assigned was coerced by the draft's own writer, so it is
	# not coerced again — but it is sealed and checked against the prop's real
	# type here, since a draft slot is deliberately laxer than the prop.
	# Identity with the current draft class proves the input is current; a stale
	# draft is read defensively onto a fresh one.
	private def check_draft(shape, input, errors, depth)
		input_class = Literal::CLASS.bind_call(input)
		draft = input_class.equal?(Literal::Draft(shape)) ? Literal::DUP.bind_call(input) : Literal::Draft(shape).new
		input_properties = input_class.literal_properties

		each_property(shape, draft, errors) do |property|
			slot = input_properties[property.name]
			value = slot ? Literal::INSTANCE_VARIABLE_GET.bind_call(input, slot.__ivar__) : Literal::Undefined

			if Literal::Undefined == value
				assign_missing(shape, draft, property, errors)
			elsif (nested = nested_type(property, value))
				assign_nested(draft, property, nested, value, errors, depth, nil)
			else
				store(draft, property, value, errors)
			end
		end
	end

	# Once anything has been reported, the shape's own code — a default, a
	# coercion, a seal — is running against values it was never promised, so a
	# raise there is the input's fault and is swallowed. With nothing reported,
	# the same raise is the shape's own bug and propagates as it does out of
	# `new`.
	private def each_property(shape, draft, errors, sound = true)
		shape.literal_properties.each do |property|
			sound = false unless yield property
		rescue Literal::Error
			raise
		rescue
			raise unless errors.any?

			# On the dup path the slot still holds the input's unjudged value,
			# which no check may read.
			ivar = property.__ivar__
			Literal::REMOVE_INSTANCE_VARIABLE.bind_call(draft, ivar) if Literal::INSTANCE_VARIABLE_DEFINED.bind_call(draft, ivar)
			sound = false
		end

		[draft, sound]
	end

	private def check_types(shape, props, errors, depth, serialization_context)
		symbolized = symbolize(props)
		draft = Literal::Draft(shape).new

		duplicates = duplicate_keys(props, symbolized, errors)
		sound = check_keys(shape, symbolized, errors) && duplicates.empty?
		props = symbolized

		each_property(shape, draft, errors, sound) do |property|
			# Which value a duplicated key meant is not knowable, so none is judged.
			if duplicates.include?(property.name)
				false
			elsif props.key?(property.name)
				if serialization_context
					assign_serialized(draft, property, props[property.name], errors, depth, serialization_context)
				else
					assign_value(draft, property, props[property.name], errors, depth)
				end
			elsif serialization_context && property.const?
				# Serializing always writes a const, so a payload without one is not
				# one this context wrote.
				errors.add(property.name, Literal::Checks::Message::MISSING)
				false
			else
				assign_missing(shape, draft, property, errors)
			end
		end
	end

	private def check_keys(shape, props, errors)
		properties = shape.literal_properties
		sound = true

		props.each_key do |key|
			next if Symbol === key && properties[key]

			errors.add_unknown(key)
			sound = false
		end

		sound
	end

	private def assign_value(draft, property, value, errors, depth)
		if property.coercion
			value = coerce(draft, property, value, errors)
			return false if REJECTED.equal?(value)
		end

		nested = nested_type(property, value)

		if nested
			assign_nested(draft, property, nested, value, errors, depth, nil)
		else
			store(draft, property, value, errors)
		end
	end

	# A serialized value already has its prop's final representation, so it is
	# decoded, not coerced, as in deserialize. An object standing for a nested
	# shape is checked rather than decoded whole, so its errors keep their paths.
	private def assign_serialized(draft, property, value, errors, depth, serialization_context)
		if Hash === value && (shape = serialized_shape(property.type, serialization_context))
			assign_nested(draft, property, shape, value, errors, depth, serialization_context)
		elsif nests_deeper?(value, MAX_DEPTH - depth)
			# Decoding a value whole recurses in the serializers, where the walk's
			# own depth bound cannot reach.
			errors.add(property.name, Literal::Checks::Message::TOO_DEEP)
			false
		elsif !(JSON_DATA === value)
			errors.add(property.name, Literal::Checks::Message.for(property.type, value))
			false
		else
			value = decode(property, value, errors, serialization_context)
			!REJECTED.equal?(value) && store_serialized(draft, property, value, errors)
		end
	end

	# A seal assumes its prop's domain, so a wrong value from outside can make
	# it raise; that is the input's fault, reported like a wrong type.
	private def store_serialized(draft, property, value, errors)
		store(draft, property, value, errors)
	rescue NoMethodError, TypeError, ArgumentError
		errors.add(property.name, Literal::Checks::Message.for(property.type, value))
		false
	end

	# Iterative, so the check cannot itself exhaust the stack.
	private def nests_deeper?(value, limit)
		pending = [[value, 0]]

		until pending.empty?
			current, level = pending.pop
			return true if level > limit

			case current
			when Hash then current.each_value { |child| pending << [child, level + 1] }
			when Array then current.each { |child| pending << [child, level + 1] }
			end
		end

		false
	end

	# Only a shape the context decodes with the plain structure serializer, and
	# only through wrappers that leave an object's decoding alone. Anything
	# else — a union an object could mean another member of, a custom codec, a
	# freeze — is decoded whole, as deserialize would.
	private def serialized_shape(type, serialization_context, seen = {}.compare_by_identity)
		# A deferred type can name itself without ever reaching a shape.
		return nil if seen.key?(type)

		seen[type] = true

		case type
		in Literal::Types::DeferredType
			serialized_shape(type.resolve, serialization_context, seen)
		in Literal::Types::NilableType if serialization_context.serializer_for_type(type).instance_of?(Literal::NilableSerializer)
			serialized_shape(type.type, serialization_context, seen)
		in Literal::Types::UnionType if type.optional?
			serialized_shape(without_undefined(type), serialization_context, seen)
		in Class if type < Literal::DataStructure && !(type <= Literal::Draft)
			type if serialization_context.serializer_for_type(type).instance_of?(Literal::StructureSerializer)
		else
			nil
		end
	end

	# Not strict: the prop's seal runs before its type is checked, in store.
	# The serialization context has already vouched for the shape, so a raise
	# here is the input's fault: a value that cannot be decoded is reported
	# like one of the wrong type.
	private def decode(property, value, errors, serialization_context)
		serialization_context.deserialize(value, type: without_undefined(property.type), strict: false)
	rescue Literal::CheckError => error
		errors.merge(error.errors.errors, under: property.name)
		REJECTED
	rescue TypeError, ArgumentError
		errors.add(property.name, Literal::Checks::Message.for(property.type, value))
		REJECTED
	end

	# Literal::Undefined is never serialized, only omitted.
	private def without_undefined(type)
		if Literal::Types::UnionType === type && type.optional?
			type.reject { |member| Literal::Undefined.equal?(member) }
		else
			type
		end
	end

	# The rescue is broad because `Integer(v)` and `Date.parse(v)` are the
	# idiom and a coercion has no other way to say no. It spans only the
	# coercion, so the type check that follows reports against the value the
	# coercion actually produced.
	private def coerce(draft, property, value, errors)
		property.coerce(value, context: Literal::Draft::API::CONTEXT.bind_call(draft))
	rescue Literal::CheckError => error
		# The coercion built a nested value that broke its own checks; those
		# surface under this prop with their paths.
		errors.merge(error.errors.errors, under: property.name)
		REJECTED
	rescue TypeError, ArgumentError
		errors.add(property.name, Literal::Checks::Message.for(property.type, value))
		REJECTED
	end

	# The seal runs before the type check because it fixes a value's final
	# representation, and that representation is what the prop's type describes;
	# checking first would reject every value a sealed prop can hold.
	private def store(draft, property, value, errors)
		value = property.apply_seal(value) if property.seal

		unless property.type === value
			errors.add(property.name, Literal::Checks::Message.for(property.type, value))
			return false
		end

		value = property.default if property.const?

		Literal::Draft::API::STORE.bind_call(draft, property.name, value)
		true
	end

	# The resolved default is coerced, sealed and type checked like a supplied
	# value, but not nested-resolved: a default is the shape's own code, not the
	# outside input the check is lenient with.
	private def assign_missing(shape, draft, property, errors)
		if property.required?
			errors.add(property.name, Literal::Checks::Message::MISSING)
			return false
		end

		errors.defaulted(property.name)

		# Only a Proc default reads the receiver, and the sync it triggers is
		# not free.
		receiver = (Proc === property.default) ? Literal::Draft::API::CONTEXT.bind_call(draft) : nil
		value = shape.__send__(:missing_prop_value, property, receiver)

		if property.coercion
			value = coerce(draft, property, value, errors)
			return false if REJECTED.equal?(value)
		end

		store(draft, property, value, errors)
	end

	# Depth first: the nested shape's own checks run and it is built before the
	# outer checks read it, so a check reads the same finished value in every
	# path. A nested value that failed its checks is not built at all — an object
	# that exists satisfies its shape's checks — so the slot stays empty and
	# taints, and an outer check reading it is held back like one reading a type
	# failure.
	private def assign_nested(draft, property, nested, value, errors, depth, serialization_context)
		if depth >= MAX_DEPTH
			errors.add(property.name, Literal::Checks::Message::TOO_DEEP)
			return false
		end

		nested_errors = Literal::Checks::Collector.new
		nested_draft, sound = run(nested, value, nested_errors, depth + 1, serialization_context)

		errors.merge(nested_errors.errors, under: property.name)

		return false if !sound || nested_errors.any?

		# Through store, so the prop's own seal and type still answer for the
		# value the nested shape built.
		store(draft, property, Literal::Draft::API::FINALIZE_UNCHECKED.bind_call(nested_draft), errors)
	end

	# A Hash stands for a shape only when exactly one is reachable — which of
	# two union members it meant is not knowable. An already-built instance is
	# taken on the strength of its construction, as `new` takes it.
	private def nested_type(property, value)
		case value
		when Hash
			return nil if property.type === value

			shapes = nested_shapes(property.type)
			(1 == shapes.size) ? shapes.first : nil
		when Literal::Draft
			# A draft the prop's type takes as it is stays one, as at finalize.
			return nil if property.type === value

			drafted = Literal::CLASS.bind_call(value).__type__
			return nil unless Class === drafted

			# The draft's own class, not the declared shape it fits: a subclass
			# draft checks as its full self.
			(nested_shapes(property.type).any? { |shape| drafted <= shape }) ? drafted : nil
		end
	end

	# Walks the DraftTransparent wrappers — the same set relaxing sees through —
	# so `draft.check` agrees with `draft.finalize`. `literal_child_types`
	# materializes a deferred type: naming itself is the only way a shape can be
	# recursive, and an unmaterialized one would read as no shape at all.
	private def nested_shapes(type, shapes = [])
		case type
		in Literal::Types::DraftTransparent
			type.literal_child_types { |child| nested_shapes(child, shapes) }
		else
			if Class === type && type < Literal::DataStructure && !(type <= Literal::Draft) && !shapes.include?(type)
				shapes << type
			end
		end

		shapes
	end

	# Which value survives interning two spellings of one name depends on input
	# order, so neither is safe to pick: the pair is reported and nothing assumed.
	private def duplicate_keys(props, symbolized, errors)
		return NO_DUPLICATES if symbolized.size == props.size

		seen = {}
		duplicates = {}

		props.each_key do |key|
			name = (String === key) ? key.to_sym : key

			if seen.key?(name) && !duplicates.key?(name)
				duplicates[name] = true
				errors.add_duplicate(name)
			end

			seen[name] = true
		end

		duplicates
	end

	# Built by hand rather than with `transform_keys`, which answers in the
	# input's own class — a HashWithIndifferentAccess would re-stringify the
	# interned keys.
	private def symbolize(props)
		props.each_key do |key|
			next unless String === key

			symbolized = {}
			props.each_pair do |k, v|
				symbolized[(String === k) ? k.to_sym : k] = v
			end

			return symbolized
		end

		props
	end
end
