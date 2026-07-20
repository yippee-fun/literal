# frozen_string_literal: true

# A typed array. Unlike a Ruby `Array`, a `Literal::Array` knows the type of its
# elements and enforces it on every mutation, so the validity established at
# construction holds for the lifetime of the object.
#
# `Literal::Array` and Ruby `Array` are deliberately distinct — neither is a
# subtype of the other. Plain arrays are welcome at the boundary, but they are
# always type-checked on the way in: through `new` and `coerce`, or as arguments
# to the binary operations. They leave through `to_a` and `to_ary` (which also
# enables splatting and destructuring), always as detached copies.
#
# The element type is fixed at construction and never changes in place — it can
# neither be widened nor narrowed. `narrow` and `widen` return new instances.
class Literal::Array
	class Generic
		include Literal::Type

		def initialize(type)
			@type = type
			freeze
		end

		attr_reader :type

		# The primitive collection type this maps to, wrapping the member type.
		def primitive_type
			Literal::Types._Array(@type)
		end

		def new(*values)
			Literal::Array.new(values, type: @type)
		end

		alias_method :[], :new

		def coerce(value)
			case value
			when self
				value
			when ::Array
				Literal::Array.new(value, type: @type)
			end
		end

		def ==(other)
			Generic === other && @type == other.type
		end

		def ===(value)
			Literal::Array === value && Literal.subtype?(value.__type__, @type)
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
			"Literal::Array(#{@type.inspect})"
		end

		def to_proc
			method(:coerce).to_proc
		end
	end

	include Enumerable

	def initialize(value, type:)
		collection_type = Literal::Types._Array(type)

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
		@__collection_type__ = collection_type || Literal::Types._Array(type)
		self
	end

	attr_reader :__type__, :__value__

	def &(other)
		__with__(@__value__ & __other_value__(other, "#&"))
	end

	def *(times)
		unless Integer === times
			raise ArgumentError.new("Cannot multiply a Literal::Array by #{times.inspect}. To join the elements into a String, use #join.")
		end

		__with__(@__value__ * times)
	end

	def +(other)
		__with__(@__value__ + __compatible_value__(other, "#+"))
	end

	def -(other)
		__with__(@__value__ - __other_value__(other, "#-"))
	end

	def <<(value)
		Literal.check(value, @__type__) do |c|
			c.fill_receiver(receiver: self, method: "#<<")
		end

		@__value__ << value
		self
	end

	def <=>(other)
		case other
		when Literal::Array
			@__value__ <=> other.__value__
		when ::Array
			@__value__ <=> other
		else
			nil
		end
	end

	def ==(other)
		Literal::Array === other && @__value__ == other.__value__
	end

	def [](index, length = nil)
		if length
			slice = @__value__[index, length]
			slice && __with__(slice)
		else
			case index
			when Range
				slice = @__value__[index]
				slice && __with__(slice)
			else
				@__value__[index]
			end
		end
	end

	def []=(index, value)
		Literal.check(value, @__type__) do |c|
			c.fill_receiver(receiver: self, method: "#[]=")
		end

		__check_padding__(index)

		@__value__[index] = value
	end

	def clear
		@__value__.clear
		self
	end

	def compact
		case (type = @__type__)
		when Literal::Types::NilableType
			Literal::Array.allocate.__initialize_without_check__(
				@__value__.compact,
				type: type.type,
			)
		when Literal::Types::UnionType
			narrowed = type.reject { |member| nil == member || NilClass == member }

			Literal::Array.allocate.__initialize_without_check__(
				@__value__.compact,
				type: narrowed,
			)
		else
			__with__(@__value__.compact)
		end
	end

	def compact!
		@__value__.compact!
		self
	end

	def concat(*others)
		values = others.map { |other| __compatible_value__(other, "#concat") }
		@__value__.concat(*values)
		self
	end

	def count(...)
		@__value__.count(...)
	end

	def delete(...)
		@__value__.delete(...)
	end

	def delete_at(...)
		@__value__.delete_at(...)
	end

	def dig(...)
		@__value__.dig(...)
	end

	def drop(n)
		__with__(@__value__.drop(n))
	end

	def drop_while(&block)
		raise ArgumentError.new("#drop_while requires a block.") unless block

		__with__(@__value__.drop_while(&block))
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
		Literal::Array === other && @__type__ == other.__type__ && @__value__.eql?(other.__value__)
	end

	def fetch(...)
		@__value__.fetch(...)
	end

	def filter_map(type, &block)
		raise ArgumentError.new("#filter_map requires a block.") unless block

		Literal::Array.new(@__value__.filter_map(&block), type:)
	end

	def first(n = nil)
		n ? __with__(@__value__.first(n)) : @__value__.first
	end

	def flat_map(type, &block)
		raise ArgumentError.new("#flat_map requires a block.") unless block

		result = []

		@__value__.each do |element|
			mapped = block.call(element)

			case mapped
			when Literal::Array
				result.concat(mapped.__value__)
			when ::Array
				result.concat(mapped)
			else
				result << mapped
			end
		end

		Literal::Array.new(result, type:)
	end

	def freeze
		@__value__.freeze
		super
	end

	def hash
		[Literal::Array, @__value__].hash
	end

	def include?(...)
		@__value__.include?(...)
	end

	def index(...)
		@__value__.index(...)
	end

	def insert(index, *values)
		values.each do |value|
			Literal.check(value, @__type__) do |c|
				c.fill_receiver(receiver: self, method: "#insert")
			end
		end

		__check_padding__(index)

		@__value__.insert(index, *values)
		self
	end

	def inspect
		"Literal::Array(#{@__type__.inspect})#{@__value__.inspect}"
	end

	alias_method :to_s, :inspect

	def join(...)
		@__value__.join(...)
	end

	def last(n = nil)
		n ? __with__(@__value__.last(n)) : @__value__.last
	end

	def map(type, &block)
		raise ArgumentError.new("#map requires a block.") unless block

		transform_type = Literal::Transforms.dig(@__type__, block)

		if transform_type && Literal.subtype?(transform_type, type)
			Literal::Array.allocate.__initialize_without_check__(
				@__value__.map(&block),
				type:,
			)
		else
			Literal::Array.new(@__value__.map(&block), type:)
		end
	end

	def map!(&block)
		raise ArgumentError.new("#map! requires a block.") unless block

		transform_type = Literal::Transforms.dig(@__type__, block)
		mapped = @__value__.map(&block)

		unless transform_type && Literal.subtype?(transform_type, @__type__)
			Literal.check(mapped, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method: "#map!")
			end
		end

		@__value__ = mapped
		self
	end

	def max(n = nil, &)
		n ? __with__(@__value__.max(n, &)) : @__value__.max(&)
	end

	def max_by(n = nil, &block)
		raise ArgumentError.new("#max_by requires a block.") unless block

		n ? __with__(@__value__.max_by(n, &block)) : @__value__.max_by(&block)
	end

	def min(n = nil, &)
		n ? __with__(@__value__.min(n, &)) : @__value__.min(&)
	end

	def min_by(n = nil, &block)
		raise ArgumentError.new("#min_by requires a block.") unless block

		n ? __with__(@__value__.min_by(n, &block)) : @__value__.min_by(&block)
	end

	def minmax(&)
		if @__value__.empty? && !(@__type__ === nil)
			raise ArgumentError.new("Cannot take the minmax of an empty Literal::Array unless its type is nilable.")
		end

		Literal::Tuple.allocate.__initialize_without_check__(
			@__value__.minmax(&),
			types: [@__type__, @__type__],
		)
	end

	def minmax_by(&block)
		raise ArgumentError.new("#minmax_by requires a block.") unless block

		if @__value__.empty? && !(@__type__ === nil)
			raise ArgumentError.new("Cannot take the minmax of an empty Literal::Array unless its type is nilable.")
		end

		Literal::Tuple.allocate.__initialize_without_check__(
			@__value__.minmax_by(&block),
			types: [@__type__, @__type__],
		)
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

		Literal::Array.allocate.__initialize_without_check__(
			@__value__.dup,
			type:,
		)
	end

	# Returns a Literal::Tuple of two typed arrays: the elements the block
	# selected, and the elements it rejected.
	def partition(&block)
		raise ArgumentError.new("#partition requires a block.") unless block

		selected, rejected = @__value__.partition(&block)
		array_type = Literal::Array(@__type__)

		Literal::Tuple.allocate.__initialize_without_check__(
			[__with__(selected), __with__(rejected)],
			types: [array_type, array_type],
		)
	end

	def pop(n = nil)
		n ? __with__(@__value__.pop(n)) : @__value__.pop
	end

	# Returns a Literal::Array of Literal::Tuples with every combination of our
	# elements and the others'. With a block, yields each tuple and returns self.
	def product(*others, &block)
		other_types = others.map { |other| __other_type__(other, "#product") }
		other_values = others.map { |other| (Literal::Array === other) ? other.__value__ : other }

		tuple_type = Literal::Tuple(@__type__, *other_types)
		tuple_types = tuple_type.types
		collection_type = Literal::Types._Tuple(@__type__, *other_types)

		rows = @__value__.product(*other_values)

		if block
			rows.each do |row|
				yield Literal::Tuple.allocate.__initialize_without_check__(row, types: tuple_types, collection_type:)
			end

			self
		else
			rows.map! do |row|
				Literal::Tuple.allocate.__initialize_without_check__(row, types: tuple_types, collection_type:)
			end

			Literal::Array.allocate.__initialize_without_check__(rows, type: tuple_type)
		end
	end

	def push(*values)
		values.each do |value|
			Literal.check(value, @__type__) do |c|
				c.fill_receiver(receiver: self, method: "#push")
			end
		end

		@__value__.push(*values)
		self
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

	def replace(other)
		@__value__.replace(__compatible_value__(other, "#replace"))
		self
	end

	def reverse
		__with__(@__value__.reverse)
	end

	def reverse!
		@__value__.reverse!
		self
	end

	def rotate(count = 1)
		__with__(@__value__.rotate(count))
	end

	def rotate!(count = 1)
		@__value__.rotate!(count)
		self
	end

	def sample(n = nil, random: Random)
		n ? __with__(@__value__.sample(n, random:)) : @__value__.sample(random:)
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

	def shift(n = nil)
		n ? __with__(@__value__.shift(n)) : @__value__.shift
	end

	def shuffle(random: Random)
		__with__(@__value__.shuffle(random:))
	end

	def shuffle!(random: Random)
		@__value__.shuffle!(random:)
		self
	end

	def size
		@__value__.size
	end

	def sort(&)
		__with__(@__value__.sort(&))
	end

	def sort!(&)
		@__value__.sort!(&)
		self
	end

	def sort_by(&block)
		raise ArgumentError.new("#sort_by requires a block.") unless block

		__with__(@__value__.sort_by(&block))
	end

	def sort_by!(&block)
		raise ArgumentError.new("#sort_by! requires a block.") unless block

		@__value__.sort_by!(&block)
		self
	end

	def sum(...)
		@__value__.sum(...)
	end

	def take(n)
		__with__(@__value__.take(n))
	end

	def take_while(&block)
		raise ArgumentError.new("#take_while requires a block.") unless block

		__with__(@__value__.take_while(&block))
	end

	def to_a
		@__value__.dup
	end

	alias_method :to_ary, :to_a

	# An array of Literal::Tuples transposes to a Literal::Tuple of typed
	# arrays (one per position), and an array of Literal::Arrays transposes to
	# its rows and columns swapped.
	def transpose
		case (type = @__type__)
		when Literal::Tuple::Generic
			types = type.types
			columns = ::Array.new(types.size) { [] }

			@__value__.each do |tuple|
				row = tuple.__value__

				i, len = 0, types.size
				while i < len
					columns[i] << row[i]
					i += 1
				end
			end

			Literal::Tuple.allocate.__initialize_without_check__(
				columns.each_with_index.map do |column, i|
					Literal::Array.allocate.__initialize_without_check__(column, type: types[i])
				end,
				types: types.map { |t| Literal::Array(t) },
			)
		when Literal::Array::Generic
			element_type = type.type
			transposed = @__value__.map(&:__value__).transpose

			transposed.map! do |row|
				Literal::Array.allocate.__initialize_without_check__(row, type: element_type)
			end

			Literal::Array.allocate.__initialize_without_check__(transposed, type:)
		else
			raise ArgumentError.new("Cannot transpose #{inspect} because its element type is not a Literal::Tuple or Literal::Array.")
		end
	end

	def uniq(&)
		__with__(@__value__.uniq(&))
	end

	def uniq!(&)
		@__value__.uniq!(&)
		self
	end

	def unshift(*values)
		values.each do |value|
			Literal.check(value, @__type__) do |c|
				c.fill_receiver(receiver: self, method: "#unshift")
			end
		end

		@__value__.unshift(*values)
		self
	end

	def widen(type)
		unless Literal.subtype?(@__type__, type)
			raise ArgumentError.new("Cannot widen #{@__type__.inspect} to #{type.inspect} because it is not a supertype.")
		end

		Literal::Array.allocate.__initialize_without_check__(
			@__value__.dup,
			type:,
		)
	end

	# Returns a Literal::Array of Literal::Tuples pairing our elements with the
	# others' elements at the same index. The result has our length: longer
	# arrays are truncated, and shorter arrays pad with nil — which is only
	# allowed if their type is nilable. With a block, yields each tuple and
	# returns nil.
	def zip(*others, &block)
		other_types = others.map { |other| __other_type__(other, "#zip") }
		other_values = others.map { |other| (Literal::Array === other) ? other.__value__ : other }

		my_length = @__value__.length

		others.each_with_index do |other, index|
			next if other.size >= my_length || other_types[index] === nil

			raise ArgumentError.new(<<~MESSAGE)
				Cannot zip #{inspect} with #{other.inspect} because the other array is shorter and its type is not nilable.

				The missing positions would be padded with nil. Either make the other array's type nilable, or make its length at least #{my_length}.
			MESSAGE
		end

		tuple_type = Literal::Tuple(@__type__, *other_types)
		tuple_types = tuple_type.types
		collection_type = Literal::Types._Tuple(@__type__, *other_types)

		rows = @__value__.zip(*other_values)

		if block
			rows.each do |row|
				yield Literal::Tuple.allocate.__initialize_without_check__(row, types: tuple_types, collection_type:)
			end

			nil
		else
			rows.map! do |row|
				Literal::Tuple.allocate.__initialize_without_check__(row, types: tuple_types, collection_type:)
			end

			Literal::Array.allocate.__initialize_without_check__(rows, type: tuple_type)
		end
	end

	def |(other)
		__with__(@__value__ | __compatible_value__(other, "#|"))
	end

	# Used to create a new Literal::Array with the same type but a new value.
	# The value is not checked, so the caller must guarantee every element
	# matches the type and that the value is not shared with another owner.
	private def __with__(value)
		Literal::Array.allocate.__initialize_without_check__(
			value,
			type: @__type__,
			collection_type: @__collection_type__,
		)
	end

	# Resolves the element type of another operand for tuple-producing
	# operations. A plain Array's element type is unknown, which is `_Any?`.
	private def __other_type__(other, method)
		case other
		when Literal::Array
			other.__type__
		when ::Array
			Literal::Types._Any?
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Array and #{other.class.inspect}.")
		end
	end

	# Unwraps the other operand for operations where the result can only
	# contain our own elements, so the other's element types don't matter.
	private def __other_value__(other, method)
		case other
		when Literal::Array
			other.__value__
		when ::Array
			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Array and #{other.class.inspect}.")
		end
	end

	# Unwraps the other operand for operations where its elements end up in our
	# array. A Literal::Array proves compatibility through its element type; a
	# plain Array is checked element by element at this boundary.
	private def __compatible_value__(other, method)
		case other
		when Literal::Array
			unless Literal.subtype?(other.__type__, @__type__)
				raise Literal::TypeError.new(
					context: Literal::TypeError::Context.new(
						expected: Literal::Array(@__type__),
						actual: other,
					),
				)
			end

			other.__value__
		when ::Array
			Literal.check(other, @__collection_type__) do |c|
				c.fill_receiver(receiver: self, method:)
			end

			other
		else
			raise ArgumentError.new("Cannot perform `#{method}` between a Literal::Array and #{other.class.inspect}.")
		end
	end

	# Writing beyond the end of the array pads the gap with nils, which is only
	# valid if our element type admits nil.
	private def __check_padding__(index)
		if Integer === index && index > @__value__.length && !(@__type__ === nil)
			raise Literal::TypeError.new(
				context: Literal::TypeError::Context.new(
					expected: @__type__,
					actual: nil,
				),
			)
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

	# TODO: Implement type-safe versions of the remaining removed methods:
	# - Literal::Hash-producing: group_by, tally, tally_by, to_h
	# - Producing Literal::Arrays of Literal::Arrays: each_slice, each_cons,
	#   chunk_while, slice_when

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
