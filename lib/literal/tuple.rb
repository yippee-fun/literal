# frozen_string_literal: true

# A typed, fixed-length tuple. Each position has its own type, checked at
# construction and on assignment, and the length never changes.
#
# `Literal::Tuple` and Ruby `Array` are deliberately distinct — neither is a
# subtype of the other. Plain arrays come in through `new` and `coerce`, always
# checked, and leave through `to_a` and `to_ary` (which also enables splatting
# and destructuring), always as detached copies. `deconstruct` supports pattern
# matching.
#
# The types are fixed at construction and never change in place.
class Literal::Tuple
	class Generic
		include Literal::Type

		def initialize(*types)
			raise Literal::ArgumentError.new("Literal::Tuple type must have at least one type.") if types.empty?

			@types = types.freeze
			freeze
		end

		attr_reader :types

		# The primitive collection type this maps to, wrapping the member types.
		def primitive_type
			Literal::Types._Tuple(*@types)
		end

		def new(*values)
			Literal::Tuple.new(values, types: @types)
		end

		alias_method :[], :new

		def coerce(value)
			case value
			when self
				value
			when ::Array
				Literal::Tuple.new(value, types: @types)
			end
		end

		def ==(other)
			Generic === other && @types == other.types
		end

		def ===(value)
			return false unless Literal::Tuple === value

			types = @types
			other_types = value.__types__

			return false unless types.size == other_types.size

			i, len = 0, types.size
			while i < len
				return false unless Literal.subtype?(other_types[i], types[i])
				i += 1
			end

			true
		end

		def >=(other, context: nil)
			case other
			when Generic
				types = @types
				other_types = other.types

				return false unless types.size == other_types.size

				i, len = 0, types.size
				while i < len
					return false unless Literal.subtype?(other_types[i], types[i], context:)
					i += 1
				end

				true
			else
				false
			end
		end

		def literal_child_types
			return enum_for(__method__) unless block_given?

			@types.each { |type| yield type }
		end

		def inspect
			"Literal::Tuple(#{@types.map(&:inspect).join(', ')})"
		end

		def to_proc
			method(:coerce).to_proc
		end
	end

	include Enumerable

	def initialize(value, types:)
		collection_type = Literal::Types._Tuple(*types)

		Literal.check(value, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__types__ = types
		@__value__ = value.dup
		@__collection_type__ = collection_type
	end

	def __initialize_without_check__(value, types:, collection_type: nil)
		@__types__ = types
		@__value__ = value
		@__collection_type__ = collection_type || Literal::Types._Tuple(*types)
		self
	end

	attr_reader :__types__, :__value__

	def <=>(other)
		case other
		when Literal::Tuple
			@__value__ <=> other.__value__
		when ::Array
			@__value__ <=> other
		else
			nil
		end
	end

	def ==(other)
		Literal::Tuple === other && @__value__ == other.__value__
	end

	# Every valid tuple index always holds a value, so lookups never need a
	# "missing" representation — an index outside the tuple is a programmer
	# error and raises, exactly like `#[]=`.
	def [](index)
		size = @__value__.size
		normalized = index

		if (Integer === normalized) && (normalized < 0)
			normalized += size
		end

		unless Integer === normalized && normalized >= 0 && normalized < size
			raise IndexError.new("Index #{index.inspect} is out of bounds for a tuple of size #{size}.")
		end

		@__value__[normalized]
	end

	def []=(index, value)
		size = @__value__.size
		normalized = index

		if (Integer === normalized) && (normalized < 0)
			normalized += size
		end

		unless Integer === normalized && normalized >= 0 && normalized < size
			raise IndexError.new("Index #{index.inspect} is out of bounds for a tuple of size #{size}. Tuples never change length.")
		end

		Literal.check(value, @__types__[normalized]) do |c|
			c.fill_receiver(receiver: self, method: "#[]=")
		end

		@__value__[normalized] = value
	end

	def deconstruct
		@__value__.dup
	end

	def each(&block)
		return @__value__.each unless block

		@__value__.each(&block)
		self
	end

	def eql?(other)
		Literal::Tuple === other && @__types__ == other.__types__ && @__value__.eql?(other.__value__)
	end

	def fetch(...)
		@__value__.fetch(...)
	end

	def first
		@__value__.first
	end

	def freeze
		@__value__.freeze
		super
	end

	def hash
		[Literal::Tuple, @__value__].hash
	end

	def include?(value)
		@__value__.include?(value)
	end

	def inspect
		"Literal::Tuple(#{@__types__.map(&:inspect).join(', ')})#{@__value__.inspect}"
	end

	alias_method :to_s, :inspect

	def last
		@__value__.last
	end

	def size
		@__value__.size
	end

	def to_a
		@__value__.dup
	end

	alias_method :to_ary, :to_a

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
