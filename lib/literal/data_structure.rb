# frozen_string_literal: true

# @api private
class Literal::DataStructure
	extend Literal::Properties

	class << self
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
	def self.from_props(props)
		instance = allocate
		properties = literal_properties
		matched = 0

		properties.each do |property|
			name = property.name

			if props.key?(name)
				matched += 1
				value = props[name]
			else
				value = missing_prop_value(property, instance)
			end

			Literal.check(value, property.type) do |context|
				context.fill_receiver(receiver: instance, method: ".from_props", label: name.name)
			end

			instance.instance_variable_set(:"@#{name.name}", value)
		end

		if matched < props.size
			unknown = props.each_key.find { |key| properties[key].nil? }
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
		_version, attributes, was_frozen = payload

		attributes.each do |key, value|
			instance_variable_set("@#{key}", value)
		end

		freeze if was_frozen
	end

	# required method for Marshal compatibility
	def marshal_dump
		[1, to_h, frozen?].freeze
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
