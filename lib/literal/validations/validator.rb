# frozen_string_literal: true

# @api private
module Literal::Validations::Validator
	extend self

	# Its own object: any real value, Literal::Undefined included, is something
	# a coercion may legitimately return.
	COERCION_FAILED = Object.new.freeze
	private_constant :COERCION_FAILED

	# SystemStackError is not a StandardError, so an unbounded walk over cyclic
	# input would escape the boundary meant to catch bad input.
	MAX_DEPTH = 64
	private_constant :MAX_DEPTH

	NO_DUPLICATES = {}.freeze
	private_constant :NO_DUPLICATES

	def validate(shape, input)
		shape = subject_shape(shape, input)

		unless shape === input || shape.respond_to?(:from_props)
			raise Literal::ArgumentError.new(
				"#{shape.name || shape.inspect} cannot validate props, because it cannot be built from them; validate an instance of it instead"
			)
		end

		errors = Literal::Validations::Collector.new
		draft, sound = run(shape, input, errors, 0)
		result_type = Literal::Result(shape, Literal::Validations::Errors)

		return result_type.failure(errors.to_errors) if !sound || errors.any?

		result_type.success((shape === input) ? input : draft.__send__(:__finalize_unchecked__))
	end

	# `only` narrows to the stipulations whose outcome depends on one property —
	# what a writer needs, since the ones it cannot have affected held before
	# the write and hold after it.
	def run_stipulations(shape, errors, only: nil, &read)
		list = only ? shape.stipulations_for(only) : shape.stipulations

		list.each do |stipulation|
			next if stipulation.reads.any? { |name| errors.tainted?(name) }

			stipulation.check(errors, &read)
		end
	end

	# A subclass instance, or a draft of a subclass, validates as its own class,
	# so the errors and the rebuilt value match what it is.
	private def subject_shape(shape, input)
		case input
		when Literal::Draft
			unless Literal::Draft(shape) === input
				drafted = input.class.__type__
				expected = shape.name || shape.inspect
				actual = drafted&.name || drafted&.inspect || "an untyped draft"

				raise Literal::ArgumentError.new(
					"#{expected}.validate expected a draft of #{expected}, got a draft of #{actual}"
				)
			end

			input.class.__type__
		when shape
			input.class
		else
			shape
		end
	end

	private def run(shape, input, errors, depth)
		draft, sound = case input
		when Literal::Draft
			check_draft(shape, input, errors, depth)
		when shape
			check_instance(shape, input, errors, depth)
		when Hash
			check_types(shape, input, errors, depth)
		else
			raise Literal::ArgumentError.new(
				"#{shape.name || shape.inspect} cannot validate a #{input.class}; expected a Hash of properties, a draft of it, or an instance of it"
			)
		end

		# An unknown key may be a typo of a known prop that then quietly
		# defaulted, so no rule runs on key confusion.
		return [draft, sound] unless errors.keys_understood?

		draft_properties = draft.class.literal_properties
		run_stipulations(shape, errors) do |name|
			ivar = draft_properties[name].__ivar__
			draft.instance_variable_defined?(ivar) ? draft.instance_variable_get(ivar) : Literal::Undefined
		end

		[draft, sound]
	end

	# A value already assigned was coerced by the draft's own writer, so it is
	# not coerced again — but it is sealed and checked against the prop's real
	# type here, since a draft slot is deliberately laxer than the prop.
	# Identity with the current draft class proves the input is current; a stale
	# draft is read defensively onto a fresh one.
	private def check_draft(shape, input, errors, depth)
		draft = input.class.equal?(Literal::Draft(shape)) ? input.dup : Literal::Draft(shape).new
		input_properties = input.class.literal_properties

		each_property(shape, draft, errors) do |property|
			slot = input_properties[property.name]
			value = slot ? input.instance_variable_get(slot.__ivar__) : Literal::Undefined

			if Literal::Undefined == value
				assign_missing(shape, draft, property, errors)
			elsif (nested = nested_type(property, value))
				assign_nested(draft, property, nested, value, errors, depth)
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
			# which no rule may read.
			ivar = property.__ivar__
			draft.remove_instance_variable(ivar) if draft.instance_variable_defined?(ivar)
			sound = false
		end

		[draft, sound]
	end

	# Values are re-checked without coercing again — a held value may have been
	# mutated in place — and a nested instance is re-validated rather than
	# trusted, since drift is exactly what the caller is asking after.
	private def check_instance(shape, instance, errors, depth)
		draft = Literal::Draft(shape).new

		each_property(shape, draft, errors) do |property|
			value = instance.instance_variable_get(property.__ivar__)

			if (nested = nested_type(property, value))
				assign_nested(draft, property, nested, value, errors, depth)
			elsif Literal::DataStructure === value
				revalidate_nested(draft, property, value, errors, depth)
			else
				store(draft, property, value, errors, seal: false)
			end
		end
	end

	# Only reached from check_instance: the input paths trust a built instance,
	# since `new` does.
	private def revalidate_nested(draft, property, value, errors, depth)
		if depth >= MAX_DEPTH
			errors.add(property.name, Literal::Validations::Message::TOO_DEEP)
			return false
		end

		nested_errors = Literal::Validations::Collector.new
		_nested_draft, sound = run(value.class, value, nested_errors, depth + 1)

		errors.merge(nested_errors.errors, under: property.name)

		return false unless sound

		store(draft, property, value, errors, seal: false)
	end

	private def check_types(shape, props, errors, depth)
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
				assign_value(draft, property, props[property.name], errors, depth)
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
			return false if COERCION_FAILED.equal?(value)
		end

		nested = nested_type(property, value)

		if nested
			assign_nested(draft, property, nested, value, errors, depth)
		else
			store(draft, property, value, errors)
		end
	end

	# The rescue is broad because `Integer(v)` and `Date.parse(v)` are the
	# idiom and a coercion has no other way to say no. It spans only the
	# coercion, so the type check that follows reports against the value the
	# coercion actually produced.
	private def coerce(draft, property, value, errors)
		property.coerce(value, context: draft.__context__)
	rescue Literal::ValidationError => error
		# The coercion built a nested value that broke its own rules; those
		# surface under this prop with their paths.
		errors.merge(error.errors.errors, under: property.name)
		COERCION_FAILED
	rescue TypeError, ArgumentError
		errors.add(property.name, Literal::Validations::Message.for(property.type, value))
		COERCION_FAILED
	end

	# The seal runs before the check because it fixes a value's final
	# representation, and that representation is what the prop's type describes;
	# checking first would reject every value a sealed prop can hold.
	# `seal: false` is for a value that is already final — one read off a built
	# instance.
	private def store(draft, property, value, errors, seal: true)
		value = property.seal.call(value) if seal && property.seal

		unless property.type === value
			errors.add(property.name, Literal::Validations::Message.for(property.type, value))
			return false
		end

		draft.__store__(property.name, value)
		true
	end

	# The resolved default is coerced, sealed and checked like a supplied value,
	# but not nested-resolved: a default is the shape's own code, not the
	# outside input validate is lenient with.
	private def assign_missing(shape, draft, property, errors)
		if property.required?
			errors.add(property.name, Literal::Validations::Message::MISSING)
			return false
		end

		# Only a Proc default reads the receiver, and the sync it triggers is
		# not free.
		receiver = (Proc === property.default) ? draft.__context__ : nil
		value = shape.__send__(:missing_prop_value, property, receiver)

		if property.coercion
			value = coerce(draft, property, value, errors)
			return false if COERCION_FAILED.equal?(value)
		end

		store(draft, property, value, errors)
	end

	private def assign_nested(draft, property, nested, value, errors, depth)
		if depth >= MAX_DEPTH
			errors.add(property.name, Literal::Validations::Message::TOO_DEEP)
			return false
		end

		nested_errors = Literal::Validations::Collector.new
		nested_draft, sound = run(nested, value, nested_errors, depth + 1)

		errors.merge(nested_errors.errors, under: property.name)

		return false unless sound

		# Through store, so the prop's own seal and type still answer for the
		# value the nested shape built.
		store(draft, property, nested_draft.__send__(:__finalize_unchecked__), errors)
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

			drafted = value.class.__type__
			return nil unless Class === drafted

			# The draft's own class, not the declared shape it fits: a subclass
			# draft validates as its full self.
			(nested_shapes(property.type).any? { |shape| drafted <= shape }) ? drafted : nil
		end
	end

	# Walks the DraftTransparent wrappers — the same set relaxing sees through —
	# so `draft.validate` agrees with `draft.finalize`. `literal_child_types`
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

	private def symbolize(props)
		props.each_key do |key|
			if String === key
				return props.transform_keys { |k| (String === k) ? k.to_sym : k }
			end
		end

		props
	end
end
