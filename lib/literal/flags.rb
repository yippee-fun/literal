# frozen_string_literal: true

class Literal::Flags
	include Enumerable

	def initialize(value = 0, **new_flags)
		if new_flags.length > 0
			value = self.class.calculate_from_hash(new_flags)
		end

		@value = value
		freeze
	end

	def __initialize_from_value__(value)
		@value = value
		freeze
	end

	attr_reader :value

	def self.define(**flags)
		raise ArgumentError if frozen?
		unique_values = flags.values
		unique_values.uniq!

		if unique_values.length != flags.length
			raise Literal::ArgumentError.new("Flags must be unique.")
		end

		invalid_flags = flags.reject { |_name, bit| bit.is_a?(Integer) }
		unless invalid_flags.empty?
			invalid_list = invalid_flags.map { |name, bit| "'#{name}' => #{bit.inspect} (#{bit.class})" }.join(", ")
			raise Literal::ArgumentError.new("Flags must be Integers, but got: #{invalid_list}")
		end

		const_set(:FLAGS, flags.dup.freeze)

		flags.each do |name, bit|
			class_eval <<~RUBY, __FILE__, __LINE__ + 1
				# frozen_string_literal: true

				def #{name}?
					@value & (2 ** #{bit}) > 0
				end
			RUBY
		end

		freeze
	end

	# () -> (Integer) -> Literal::Flags
	def self.to_proc
		proc { |value| new(value) }
	end

	# (Integer) -> String
	def self.calculate_bit_string(value)
		value.to_s(2).rjust(self::BITS, "0")
	end

	# (Array(Boolean)) -> Integer
	def self.calculate_from_array(array)
		array.reverse_each.with_index.reduce(0) do |value, (bit, index)|
			value | (bit ? 1 << index : 0)
		end
	end

	# (Hash(Symbol, Boolean)) -> Integer
	def self.calculate_from_hash(hash)
		flags = self::FLAGS
		hash.reduce(0) do |value, (key, bit)|
			value | (bit ? 2 ** flags.fetch(key) : 0)
		end
	end

	# (Integer) -> Array(Symbol)
	def self.calculate_tokens(value)
		flags = self::FLAGS
		flags.keys.select { |t| value & (2 ** flags.fetch(t)) > 0 }
	end

	# (Integer) -> Array(Boolean)
	def self.calculate_array(value)
		bits = self::BITS
		Array.new(bits) { |i| (value & (2 ** (bits - 1 - i)) > 0) }
	end

	# (Array(Symbol)) -> Integer
	def self.calculate_from_tokens(tokens)
		flags = self::FLAGS
		tokens.reduce(0) { |f, t| f | (2 ** flags.fetch(t)) }
	end

	# (Integer) -> Hash(Symbol, Boolean)
	def self.calculate_hash_from_value(value)
		self::FLAGS.transform_values do |bit|
			(value & (2 ** bit)) > 0
		end
	end

	# () -> Array(Symbol)
	def self.keys
		@flags.keys
	end

	# (String) -> Literal::Flags
	def self.from_bit_string(bit_string)
		from_int(bit_string.to_i(2))
	end

	# (Array(Boolean)) -> Literal::Flags
	def self.from_array(array)
		if array.length != self::BITS
			raise Literal::ArgumentError.new("The array must have #{self::BITS} items.")
		end

		from_int(calculate_from_array(array))
	end

	# (Array(Symbol)) -> Literal::Flags
	def self.from_tokens(tokens)
		from_int(calculate_from_tokens(tokens))
	end

	# (Integer) -> Literal::Flags
	def self.from_int(value)
		allocate.__initialize_from_value__(value)
	end

	# (String) -> Integer
	def self.unpack_int(value)
		value.unpack1(self::PACKER)
	end

	# (String) -> Literal::Flags
	def self.unpack(value)
		new(unpack_int(value))
	end

	# () -> String
	def pack
		[@value].pack(self.class::PACKER)
	end

	def with(**attributes)
		new_val = attributes.reduce(value) do |value, (k, v)|
			v ? value |= bitmap(k) : value &= ~(bitmap(k))
			value
		end

		self.class.allocate.__initialize_from_value__(new_val)
	end

	# () -> String
	def inspect
		to_h.inspect
	end

	# () -> Hash(Symbol, Boolean)
	def to_h
		self.class.calculate_hash_from_value(@value)
	end

	def each
		self.class::FLAGS.each do |key, bit|
			yield key, @value & (2 ** bit) > 0
		end
	end

	# (Symbol) -> Boolean
	def [](key)
		@value & (bitmap(key)) > 0
	end

	def |(other)
		case other
		when Literal::Flags
			self.class.new(@value | other.value)
		when Integer
			self.class.new(@value | other)
		end
	end

	def &(other)
		case other
		when Literal::Flags
			self.class.new(@value & other.value)
		when Integer
			self.class.new(@value & other)
		end
	end

	def to_i
		@value
	end

	def to_bit_string
		self.class.calculate_bit_string(@value)
	end

	def to_tokens
		self.class.calculate_tokens(@value)
	end

	def to_a
		self.class.calculate_array(@value)
	end

	alias_method :deconstruct, :to_a

	def deconstruct_keys(keys = nil)
		if keys
			keys.to_h do |key|
				[key, @value & (bitmap(key)) > 0]
			end
		else
			to_h
		end
	end

	private def bitmap(key)
		2 ** self.class::FLAGS.fetch(key)
	end
end
