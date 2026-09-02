# frozen_string_literal: true

# @api private
class Literal::DataStructure
	extend Literal::Properties

	class << self
		# Build an instance through a draft: yields a draft of this class to
		# the block, then finalizes it. Any arguments are passed through to
		# the draft's constructor.
		def build(...)
			Literal::Draft(self).build(...)
		end

		def literal_child_types
			return enum_for(__method__) unless block_given?

			literal_properties.each { |property| yield property.type }
		end
	end

	def self.from_pack(payload)
		object = allocate
		object.marshal_load(payload)
		object
	end

	# Construct an instance from a Hash of property values keyed by Symbol
	# property name — the inverse of #to_h. Where .new takes constructor
	# arguments, each according to its property's kind and subject to
	# coercion, this takes final property values: it allocates the instance
	# and assigns them directly, type checking each value but never coercing.
	# Omitted properties fall back to their defaults. Like from_pack, it does
	# not run the initializer or after_initialize.
	# Construct an instance from another object's matching properties — e.g.
	# an instance of the class a slice was taken from. Properties the object
	# doesn't have fall back to their defaults, and anything extra in its
	# to_h is ignored. The values are final: type checked, never coerced.
	def self.from(original)
		from_props(original.to_h.slice(*literal_properties.map(&:name)))
	end

	def self.from_props(props)
		instance = __literal_from_props__(props)
		instance.__send__(:__literal_run_checks__)
		instance
	end

	# from_props without the shape's checks, for a caller that has already run
	# them — Literal::Checks::Checker, which collects them against a
	# draft rather than raising. Every other path must go through from_props, or
	# an object that breaks its shape's checks could be handed out.
	#
	# `seal: false` is for values that are already final, having been sealed by
	# that caller — seals fix a representation once, not once per hop.
	private_class_method def self.__literal_from_props__(props, seal: true)
		instance = allocate
		matched = instance.__send__(:__literal_assign_props__, props, ".from_props", seal:)

		if matched < props.size
			unknown = props.each_key.find { |key| literal_properties[key].nil? }
			raise NameError.new("unknown attribute: #{unknown.inspect} for #{self}")
		end

		instance
	end

	# The value a property takes when absent from from_props input, mirroring
	# what the initializer resolves for an omitted parameter.
	private_class_method def self.missing_prop_value(property, instance)
		case property.kind
		when :*
			[]
		when :**
			{}
		else
			if property.default?
				property.default_value(instance)
			elsif property.undefinable?
				Literal::Undefined
			elsif property.type === nil
				nil
			else
				raise Literal::ArgumentError.new("Missing property #{property.name.inspect} for #{self}")
			end
		end
	end

	def to_h
		{}
	end

	def [](key)
		case key
		when Symbol
		when String
			key = key.intern
		else
			raise TypeError.new("expected a string or symbol, got #{key.inspect.class}")
		end

		prop = self.class.literal_properties[key] || raise(NameError.new("unknown attribute: #{key.inspect} for #{self.class}"))
		__send__(prop.name)
	end

	alias to_hash to_h

	def deconstruct
		to_h.values
	end

	def deconstruct_keys(keys)
		h = to_h
		keys ? h.slice(*keys) : h
	end

	def as_pack
		marshal_dump
	end

	# required method for Marshal compatibility
	def marshal_load(payload)
		_version, attributes, was_frozen, frozen_values = payload

		# Marshal.load rebuilds contained objects unfrozen, so restore the
		# frozen state each value had when it was dumped — before the type
		# check, which may require it. Version 1 payloads carry no list.
		frozen_values&.each do |name|
			attributes[name].freeze if attributes.key?(name)
		end

		# Seals don't apply here: they belong to construction, and a loaded
		# object was constructed — and sealed — before it was dumped. The
		# frozen state recorded at dump is what gets restored.
		__literal_assign_props__(attributes, "#marshal_load", seal: false)

		freeze if was_frozen

		# Restoring a dumped object is still construction: an object that breaks
		# the shape's checks must not come back to life either.
		__literal_run_checks__
	end

	# Assign final property values from a Hash keyed by Symbol property name,
	# type checking each value but never coercing. Seals apply unless the
	# caller is restoring already-constructed state — they fix a value's
	# final representation, not its input. Missing properties resolve the
	# same way an omitted initializer parameter would. Keys that don't match
	# a property are ignored — for marshalling, they're values for properties
	# that have since been removed. Returns the number of keys that matched a
	# property so callers can be stricter.
	private def __literal_assign_props__(props, method_name, seal: true)
		properties = self.class.literal_properties
		matched = 0

		properties.each do |property|
			name = property.name

			if props.key?(name)
				matched += 1
				value = props[name]
			else
				value = self.class.__send__(:missing_prop_value, property, self)
			end

			if seal && (property_seal = property.seal)
				value = property_seal.call(value)
			end

			Literal.check(value, property.type) do |context|
				context.fill_receiver(receiver: self, method: method_name, label: name.name)
			end

			instance_variable_set(:"@#{name.name}", value)
		end

		matched
	end

	# required method for Marshal compatibility
	def marshal_dump
		attributes = to_h

		# Record which values are frozen so marshal_load can restore that
		# state. Immediates are skipped — they always load frozen anyway.
		frozen_values = attributes.keys.select do |name|
			case (value = attributes[name])
			when Integer, Float, Symbol, nil, true, false
				false
			else
				Literal::FROZEN.bind_call(value)
			end
		end

		[2, attributes, frozen?, frozen_values.freeze].freeze
	end

	def hash
		self.class.hash
	end

	def ==(other)
		self.class == other.class
	end

	alias_method :eql?, :==

	def self.__generate_literal_methods__(new_property, buffer = +"")
		super
		literal_properties.generate_hash(buffer)
		literal_properties.generate_eq(buffer)
		buffer
	end
end
