# frozen_string_literal: true

# A typed hash. Unlike a Ruby `Hash`, a `Literal::Hash` knows the types of its
# keys and values and enforces them on every mutation, so the validity
# established at construction holds for the lifetime of the object.
#
# `Literal::Hash` and Ruby `Hash` are deliberately distinct — neither is a
# subtype of the other. Plain hashes are welcome at the boundary, but they are
# always type-checked on the way in: through `new` and `coerce`, or as
# arguments to `merge` and friends. They leave through `to_h` and `to_hash`
# (which also enables double-splatting), always as detached copies.
#
# The key and value types are fixed at construction and never change in place —
# they can neither be widened nor narrowed. `narrow` and `widen` return new
# instances.
class Literal::Hash
	class Generic
		include Literal::Type

		def initialize(key_type, value_type)
			@key_type = key_type
			@value_type = value_type
			freeze
		end

		attr_reader :key_type, :value_type

		# The primitive collection type this maps to, wrapping the member types.
		def primitive_type
			Literal::Types._Hash(@key_type, @value_type)
		end

		def new(value = {})
			Literal::Hash.new(value, key_type: @key_type, value_type: @value_type)
		end

		alias_method :[], :new

		def coerce(value)
			case value
			when self
				value
			when ::Hash
				Literal::Hash.new(value, key_type: @key_type, value_type: @value_type)
			end
		end

		def ==(other)
			Generic === other && @key_type == other.key_type && @value_type == other.value_type
		end

		def ===(value)
			Literal::Hash === value &&
				Literal.subtype?(value.__key_type__, @key_type) &&
				Literal.subtype?(value.__value_type__, @value_type)
		end

		def >=(other, context: nil)
			case other
			when Generic
				Literal.subtype?(other.key_type, @key_type, context:) &&
					Literal.subtype?(other.value_type, @value_type, context:)
			else
				false
			end
		end

		def literal_child_types
			return enum_for(__method__) unless block_given?

			yield @key_type
			yield @value_type
		end

		def inspect
			"Literal::Hash(#{@key_type.inspect}, #{@value_type.inspect})"
		end

		def to_proc
			method(:coerce).to_proc
		end
	end

	include Enumerable

	def initialize(value, key_type:, value_type:)
		collection_type = Literal::Types._Hash(key_type, value_type)

		Literal.check(value, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__key_type__ = key_type
		@__value_type__ = value_type
		@__value__ = value.dup
		@__collection_type__ = collection_type
	end

	def __initialize_without_check__(value, key_type:, value_type:, collection_type: nil)
		@__key_type__ = key_type
		@__value_type__ = value_type
		@__value__ = value
		@__collection_type__ = collection_type || Literal::Types._Hash(key_type, value_type)
		self
	end

	attr_reader :__key_type__, :__value_type__, :__value__

	def ==(other)
		Literal::Hash === other && @__value__ == other.__value__
	end

	def [](key)
		@__value__[key]
	end

	def []=(key, value)
		Literal.check(key, @__key_type__) do |c|
			c.fill_receiver(receiver: self, method: "#[]=")
		end

		Literal.check(value, @__value_type__) do |c|
			c.fill_receiver(receiver: self, method: "#[]=")
		end

		@__value__[key] = value
	end

	def clear
		@__value__.clear
		self
	end

	def compact
		case (value_type = @__value_type__)
		when Literal::Types::NilableType
			Literal::Hash.allocate.__initialize_without_check__(
				@__value__.compact,
				key_type: @__key_type__,
				value_type: value_type.type,
			)
		when Literal::Types::UnionType
			narrowed = value_type.reject { |member| nil == member || NilClass == member }

			Literal::Hash.allocate.__initialize_without_check__(
				@__value__.compact,
				key_type: @__key_type__,
				value_type: narrowed,
			)
		else
			__with__(@__value__.compact)
		end
	end

	def compact!
		@__value__.compact!
		self
	end

	def delete(...)
		@__value__.delete(...)
	end

	def dig(...)
		@__value__.dig(...)
	end

	def each(&block)
		return @__value__.each unless block

		@__value__.each(&block)
		self
	end

	def empty?
		@__value__.empty?
	end

	def eql?(other)
		Literal::Hash === other &&
			@__key_type__ == other.__key_type__ &&
			@__value_type__ == other.__value_type__ &&
			@__value__.eql?(other.__value__)
	end

	# Returns a copy without the given keys. No checks are needed because the
	# result can only contain our own entries.
	def except(*keys)
		__with__(@__value__.except(*keys))
	end

	def fetch(...)
		@__value__.fetch(...)
	end

	def freeze
		@__value__.freeze
		super
	end

	def hash
		[Literal::Hash, @__value__].hash
	end

	def inspect
		"Literal::Hash(#{@__key_type__.inspect}, #{@__value_type__.inspect})#{@__value__.inspect}"
	end

	alias_method :to_s, :inspect

	def invert
		Literal::Hash.allocate.__initialize_without_check__(
			@__value__.invert,
			key_type: @__value_type__,
			value_type: @__key_type__,
		)
	end

	def key?(key)
		@__value__.key?(key)
	end

	def keys
		Literal::Array.allocate.__initialize_without_check__(
			@__value__.keys,
			type: @__key_type__,
		)
	end

	def merge(*others, &block)
		merged = @__value__.merge(
			*others.map { |other| __compatible_value__(other, "#merge") }, &block
		)

		# The operands are checked, but a conflict block can resolve to anything.
		if block
			Literal.check(merged, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method: "#merge")
			end
		end

		__with__(merged)
	end

	def merge!(*others, &block)
		values = others.map { |other| __compatible_value__(other, "#merge!") }

		if block
			merged = @__value__.merge(*values, &block)

			Literal.check(merged, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method: "#merge!")
			end

			@__value__.replace(merged)
		else
			@__value__.merge!(*values)
		end

		self
	end

	def narrow(key_type: @__key_type__, value_type: @__value_type__)
		unless Literal.subtype?(key_type, @__key_type__) && Literal.subtype?(value_type, @__value_type__)
			raise ArgumentError.new("Cannot narrow #{inspect_generic} to #{Literal::Hash(key_type, value_type).inspect} because it is not a subtype.")
		end

		unless key_type == @__key_type__ && value_type == @__value_type__
			@__value__.each do |key, value|
				Literal.check(key, key_type) do |c|
					c.fill_receiver(receiver: self, method: "#narrow")
				end

				Literal.check(value, value_type) do |c|
					c.fill_receiver(receiver: self, method: "#narrow")
				end
			end
		end

		Literal::Hash.allocate.__initialize_without_check__(
			@__value__.dup,
			key_type:,
			value_type:,
		)
	end

	def reject(&block)
		raise ArgumentError.new("#reject requires a block.") unless block

		__with__(@__value__.reject(&block))
	end

	def reject!(&block)
		raise ArgumentError.new("#reject! requires a block.") unless block

		@__value__.reject!(&block)
		self
	end

	def select(&block)
		raise ArgumentError.new("#select requires a block.") unless block

		__with__(@__value__.select(&block))
	end

	def select!(&block)
		raise ArgumentError.new("#select! requires a block.") unless block

		@__value__.select!(&block)
		self
	end

	def size
		@__value__.size
	end

	# Returns a copy with only the given keys. No checks are needed because the
	# result can only contain our own entries.
	def slice(*keys)
		__with__(@__value__.slice(*keys))
	end

	def to_h
		@__value__.dup
	end

	alias_method :to_hash, :to_h

	def transform_keys(type, &block)
		raise ArgumentError.new("#transform_keys requires a block.") unless block

		transformed = @__value__.transform_keys(&block)
		collection_type = Literal::Types._Hash(type, @__value_type__)

		Literal.check(transformed, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#transform_keys")
		end

		Literal::Hash.allocate.__initialize_without_check__(
			transformed,
			key_type: type,
			value_type: @__value_type__,
			collection_type:,
		)
	end

	def transform_values(type, &block)
		raise ArgumentError.new("#transform_values requires a block.") unless block

		transformed = @__value__.transform_values(&block)
		collection_type = Literal::Types._Hash(@__key_type__, type)

		Literal.check(transformed, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#transform_values")
		end

		Literal::Hash.allocate.__initialize_without_check__(
			transformed,
			key_type: @__key_type__,
			value_type: type,
			collection_type:,
		)
	end

	def value?(value)
		@__value__.value?(value)
	end

	def values
		Literal::Array.allocate.__initialize_without_check__(
			@__value__.values,
			type: @__value_type__,
		)
	end

	def widen(key_type: @__key_type__, value_type: @__value_type__)
		unless Literal.subtype?(@__key_type__, key_type) && Literal.subtype?(@__value_type__, value_type)
			raise ArgumentError.new("Cannot widen #{inspect_generic} to #{Literal::Hash(key_type, value_type).inspect} because it is not a supertype.")
		end

		Literal::Hash.allocate.__initialize_without_check__(
			@__value__.dup,
			key_type:,
			value_type:,
		)
	end

	# Used to create a new Literal::Hash with the same types but a new value.
	# The value is not checked, so the caller must guarantee every entry
	# matches the types and that the value is not shared with another owner.
	private def __with__(value)
		Literal::Hash.allocate.__initialize_without_check__(
			value,
			key_type: @__key_type__,
			value_type: @__value_type__,
			collection_type: @__collection_type__,
		)
	end

	# Unwraps the other operand for operations where its entries end up in our
	# hash. A Literal::Hash proves compatibility through its key and value
	# types; a plain Hash is checked entry by entry at this boundary.
	private def __compatible_value__(other, method)
		case other
		when Literal::Hash
			unless Literal.subtype?(other.__key_type__, @__key_type__) && Literal.subtype?(other.__value_type__, @__value_type__)
				raise Literal::TypeError.new(
					context: Literal::TypeError::Context.new(
						expected: Literal::Hash(@__key_type__, @__value_type__),
						actual: other,
					),
				)
			end

			other.__value__
		when ::Hash
			Literal.check(other, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method:)
			end

			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Hash and #{other.class.inspect}.")
		end
	end

	private def inspect_generic
		"Literal::Hash(#{@__key_type__.inspect}, #{@__value_type__.inspect})"
	end

	private def initialize_copy(source)
		super
		@__value__ = @__value__.dup
	end

	private def initialize_clone(source, freeze: nil)
		super(source)
		@__value__ = source.__value__.clone(freeze:)
		self
	end

	# The Enumerable methods below are supported as-is because they never leak
	# an untyped collection. Everything else Enumerable defines is removed —
	# either we provide our own type-safe version above, or the method is
	# unsupported until we can provide one.
	SUPPORTED_ENUMERABLE_METHODS = Set[
		:all?,
		:any?,
		:each_with_index,
		:each_with_object,
		:find,
		:none?,
		:one?,
		:reduce,
	].freeze

	Enumerable.instance_methods.each do |method|
		next if SUPPORTED_ENUMERABLE_METHODS.include?(method)

		undef_method(method) if instance_method(method).owner == Enumerable
	end
end
