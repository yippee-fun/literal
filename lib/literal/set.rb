# frozen_string_literal: true

# A typed set. Unlike a Ruby `Set`, a `Literal::Set` knows the type of its
# members and enforces it on every mutation, so the validity established at
# construction holds for the lifetime of the object.
#
# `Literal::Set` and Ruby `Set` are deliberately distinct — neither is a
# subtype of the other. Plain sets and arrays are welcome at the boundary, but
# they are always type-checked on the way in: through `new` and `coerce`, or as
# arguments to the binary operations. They leave through `to_a` and `to_set`,
# always as detached copies.
#
# The member type is fixed at construction and never changes in place — it can
# neither be widened nor narrowed. `narrow` and `widen` return new instances.
class Literal::Set
	class Generic
		include Literal::Type

		def initialize(type)
			@type = type
			freeze
		end

		attr_reader :type

		def new(*values)
			Literal::Set.new(::Set.new(values), type: @type)
		end

		alias_method :[], :new

		def coerce(value)
			case value
			when self
				value
			when ::Set
				Literal::Set.new(value, type: @type)
			when ::Array
				Literal::Set.new(::Set.new(value), type: @type)
			end
		end

		def ==(other)
			Generic === other && @type == other.type
		end

		def ===(value)
			Literal::Set === value && Literal.subtype?(value.__type__, @type)
		end

		def >=(other, context: nil)
			case other
			when Generic
				Literal.subtype?(other.type, @type, context:)
			else
				false
			end
		end

		def literal_child_types
			return enum_for(__method__) unless block_given?

			yield @type
		end

		def inspect
			"Literal::Set(#{@type.inspect})"
		end

		def to_proc
			method(:coerce).to_proc
		end
	end

	include Enumerable

	def initialize(value, type:)
		collection_type = Literal::Types._Set(type)

		Literal.check(value, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__type__ = type
		@__value__ = value.dup
		@__collection_type__ = collection_type
	end

	def __initialize_without_check__(value, type:, collection_type: nil)
		@__type__ = type
		@__value__ = value
		@__collection_type__ = collection_type || Literal::Types._Set(type)
		self
	end

	attr_reader :__type__, :__value__

	def &(other)
		__with__(@__value__ & __other_value__(other, "#&"))
	end

	def -(other)
		__with__(@__value__ - __other_value__(other, "#-"))
	end

	def ==(other)
		Literal::Set === other && @__value__ == other.__value__
	end

	def ^(other)
		__with__(@__value__ ^ __compatible_value__(other, "#^"))
	end

	def add(value)
		Literal.check(value, @__type__) do |c|
			c.fill_receiver(receiver: self, method: "#add")
		end

		@__value__.add(value)
		self
	end

	alias_method :<<, :add

	def clear
		@__value__.clear
		self
	end

	def delete(value)
		@__value__.delete(value)
		self
	end

	def disjoint?(other)
		@__value__.disjoint?(__other_value__(other, "#disjoint?"))
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
		Literal::Set === other && @__type__ == other.__type__ && @__value__.eql?(other.__value__)
	end

	def freeze
		@__value__.freeze
		super
	end

	def hash
		[Literal::Set, @__value__].hash
	end

	def include?(value)
		@__value__.include?(value)
	end

	def inspect
		"Literal::Set(#{@__type__.inspect}){#{@__value__.to_a.map(&:inspect).join(', ')}}"
	end

	alias_method :to_s, :inspect

	def intersect?(other)
		@__value__.intersect?(__other_value__(other, "#intersect?"))
	end

	def map(type, &block)
		raise ArgumentError.new("#map requires a block.") unless block

		transform_type = Literal::Transforms.dig(@__type__, block)
		collection_type = Literal::Types._Set(type)
		mapped = ::Set.new

		@__value__.each do |value|
			mapped.add(block.call(value))
		end

		unless transform_type && Literal.subtype?(transform_type, type)
			Literal.check(mapped, collection_type) do |c|
				c.fill_receiver(receiver: self, method: "#map")
			end
		end

		Literal::Set.allocate.__initialize_without_check__(
			mapped,
			type:,
			collection_type:,
		)
	end

	def map!(&block)
		raise ArgumentError.new("#map! requires a block.") unless block

		transform_type = Literal::Transforms.dig(@__type__, block)
		mapped = ::Set.new

		@__value__.each do |value|
			mapped.add(block.call(value))
		end

		unless transform_type && Literal.subtype?(transform_type, @__type__)
			Literal.check(mapped, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method: "#map!")
			end
		end

		@__value__ = mapped
		self
	end

	def merge(*others)
		values = others.map { |other| __compatible_value__(other, "#merge") }

		values.each do |value|
			@__value__.merge(value)
		end

		self
	end

	def narrow(type)
		unless Literal.subtype?(type, @__type__)
			raise ArgumentError.new("Cannot narrow #{@__type__.inspect} to #{type.inspect} because it is not a subtype.")
		end

		unless type == @__type__
			@__value__.each do |value|
				Literal.check(value, type) do |c|
					c.fill_receiver(receiver: self, method: "#narrow")
				end
			end
		end

		Literal::Set.allocate.__initialize_without_check__(
			@__value__.dup,
			type:,
		)
	end

	def reject(&block)
		raise ArgumentError.new("#reject requires a block.") unless block

		__with__(@__value__.reject(&block).to_set)
	end

	def reject!(&block)
		raise ArgumentError.new("#reject! requires a block.") unless block

		@__value__.reject!(&block)
		self
	end

	def replace(other)
		@__value__.replace(__compatible_value__(other, "#replace"))
		self
	end

	def select(&block)
		raise ArgumentError.new("#select requires a block.") unless block

		__with__(@__value__.select(&block).to_set)
	end

	def select!(&block)
		raise ArgumentError.new("#select! requires a block.") unless block

		@__value__.select!(&block)
		self
	end

	def size
		@__value__.size
	end

	# Returns a sorted Literal::Array of the members.
	def sort(&)
		Literal::Array.allocate.__initialize_without_check__(
			@__value__.sort(&),
			type: @__type__,
		)
	end

	# Returns a Literal::Array of the members, sorted by the block's result.
	def sort_by(&block)
		raise ArgumentError.new("#sort_by requires a block.") unless block

		Literal::Array.allocate.__initialize_without_check__(
			@__value__.sort_by(&block),
			type: @__type__,
		)
	end

	def subset?(other)
		@__value__.subset?(__other_set__(other, "#subset?"))
	end

	def subtract(other)
		@__value__.subtract(__other_value__(other, "#subtract"))
		self
	end

	def superset?(other)
		@__value__.superset?(__other_set__(other, "#superset?"))
	end

	def to_a
		@__value__.to_a
	end

	def to_set
		@__value__.dup
	end

	def widen(type)
		unless Literal.subtype?(@__type__, type)
			raise ArgumentError.new("Cannot widen #{@__type__.inspect} to #{type.inspect} because it is not a supertype.")
		end

		Literal::Set.allocate.__initialize_without_check__(
			@__value__.dup,
			type:,
		)
	end

	def |(other)
		__with__(@__value__ | __compatible_value__(other, "#|"))
	end

	# Used to create a new Literal::Set with the same type but a new value.
	# The value is not checked, so the caller must guarantee every member
	# matches the type and that the value is not shared with another owner.
	private def __with__(value)
		Literal::Set.allocate.__initialize_without_check__(
			value,
			type: @__type__,
			collection_type: @__collection_type__,
		)
	end

	# Unwraps the other operand for operations where the result can only
	# contain our own members, so the other's member types don't matter.
	private def __other_value__(other, method)
		case other
		when Literal::Set
			other.__value__
		when ::Set, ::Array
			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Set and #{other.class.inspect}.")
		end
	end

	# Unwraps the other operand for operations that require a plain Set.
	private def __other_set__(other, method)
		case other
		when Literal::Set
			other.__value__
		when ::Set
			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Set and #{other.class.inspect}.")
		end
	end

	# Unwraps the other operand for operations where its members end up in our
	# set. A Literal::Set proves compatibility through its member type; a plain
	# Set or Array is checked member by member at this boundary.
	private def __compatible_value__(other, method)
		case other
		when Literal::Set
			unless Literal.subtype?(other.__type__, @__type__)
				raise Literal::TypeError.new(
					context: Literal::TypeError::Context.new(
						expected: Literal::Set(@__type__),
						actual: other,
					),
				)
			end

			other.__value__
		when ::Set, ::Array
			other.each do |value|
				Literal.check(value, @__type__) do |c|
					c.fill_receiver(receiver: self, method:)
				end
			end

			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Set and #{other.class.inspect}.")
		end
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
