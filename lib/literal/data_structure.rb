# frozen_string_literal: true

# @api private
class Literal::DataStructure
	extend Literal::Properties

	def self.from_pack(payload)
		object = allocate
		object.marshal_load(payload)
		object
	end

	def to_h
		{}
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
		self.class === other && other.class.literal_properties.empty?
	end

	alias_method :eql?, :==

	def self.__generate_literal_methods__(new_property, buffer = +"")
		super
		literal_properties.generate_hash(buffer)
		literal_properties.generate_eq(buffer)
		buffer
	end
end
