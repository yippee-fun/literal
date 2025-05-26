# frozen_string_literal: true

class Literal::Array
	class Generic
		include Literal::Type

		def initialize(type)
			@type = type
		end

		attr_reader :type

		def new(*value)
			Literal::Array.new(value, type: @type)
		end

		alias_method :[], :new

		def ===(value)
			Literal::Array === value && Literal.subtype?(value.__type__, @type)
		end

		def >=(other)
			case other
			when Literal::Array::Generic
				Literal.subtype?(other.type, @type)
			else
				false
			end
		end

		def inspect
			"Literal::Array(#{@type.inspect})"
		end

		def coerce(value)
			case value
			when self
				value
			when Array
				Literal::Array.new(value, type: @type)
			end
		end

		def to_proc
			method(:coerce).to_proc
		end
	end

	include Enumerable
	include Literal::Types

	def initialize(value, type:)
		Literal.check(value, _Array(type)) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__type__ = type
		@__value__ = value
	end

	def __initialize_without_check__(value, type:)
		@__type__ = type
		@__value__ = value
		self
	end

	# Used to create a new Literal::Array with the same type and collection type but a new value. The value is not checked.
	def __with__(value)
		Literal::Array.allocate.__initialize_without_check__(
			value,
			type: @__type__,
		)
	end

	attr_reader :__type__, :__value__

	def &(other)
		case other
		when ::Array
			__with__(@__value__ & other)
		when Literal::Array
			__with__(@__value__ & other.__value__)
		else
			raise ArgumentError.new("Cannot perform bitwise AND with #{other.class.name}.")
		end
	end

	def *(times)
		case times
		when String
			@__value__ * times
		else
			__with__(@__value__ * times)
		end
	end

	def +(other)
		case other
		when ::Array
			Literal.check(other, _Array(@__type__)) do |c|
				c.fill_receiver(receiver: self, method: "#+")
			end

			__with__(@__value__ + other)
		when Literal::Array(@__type__)
			__with__(@__value__ + other.__value__)
		when Literal::Array
			raise Literal::TypeError.new(
				context: Literal::TypeError::Context.new(
					expected: Literal::Array(@__type__),
					actual: other
				)
			)
		else
			raise ArgumentError.new("Cannot perform `+` with #{other.class.name}.")
		end
	end

	def -(other)
		case other
		when ::Array
			__with__(@__value__ - other)
		when Literal::Array
			__with__(@__value__ - other.__value__)
		else
			raise ArgumentError.new("Cannot perform `-` with #{other.class.name}.")
		end
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
		when ::Array
			@__value__ <=> other
		when Literal::Array
			@__value__ <=> other.__value__
		else
			raise ArgumentError.new("Cannot perform `<=>` with #{other.class.name}.")
		end
	end

	def ==(other)
		Literal::Array === other && @__value__ == other.__value__
	end

	def [](index)
		@__value__[index]
	end

	def []=(index, value)
		Literal.check(value, @__type__) do |c|
			c.fill_receiver(receiver: self, method: "#[]=")
		end

		@__value__[index] = value
	end

	def all?(...)
		@__value__.all?(...)
	end

	def any?(...)
		@__value__.any?(...)
	end

	def assoc(...)
		@__value__.assoc(...)
	end

	def at(...)
		@__value__.at(...)
	end

	def bsearch(...)
		@__value__.bsearch(...)
	end

	def clear(...)
		@__value__.clear(...)
		self
	end

	def combination(...)
		@__value__.combination(...)
		self
	end

	def compact
		# @TODO if this is an array of nils, we should return an emtpy array
		__with__(@__value__)
	end

	def compact!
		# @TODO if this is an array of nils, we should set @__value__ = [] and return self
		nil
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

	def delete_if(...)
		@__value__.delete_if(...)
		self
	end

	def dig(...)
		@__value__.dig(...)
	end

	def drop(...)
		__with__(@__value__.drop(...))
	end

	def drop_while(...)
		__with__(@__value__.drop_while(...))
	end

	def each(...)
		@__value__.each(...)
	end

	def each_index(...)
		@__value__.each_index(...)
	end

	def empty?
		@__value__.empty?
	end

	alias_method :eql?, :==

	def filter(...)
		__with__(@__value__.filter(...))
	end

	def filter!(...)
		@__value__.filter!(...)
		self
	end

	def flatten(...)
		__with__(@__value__.flatten(...))
	end

	def first(...)
		@__value__.first(...)
	end

	def flatten!(...)
		@__value__.flatten!(...) ? self : nil
	end

	def freeze
		@__value__.freeze
		super
	end

	def hash
		[self.class, @__value__].hash
	end

	def include?(...)
		@__value__.include?(...)
	end

	alias_method :index, :find_index

	def insert(index, *value)
		Literal.check(value, _Array(@__type__)) do |c|
			c.fill_receiver(receiver: self, method: "#insert")
		end

		@__value__.insert(index, *value)
		self
	end

	def inspect
		"Literal::Array(#{@__type__.inspect})#{@__value__.inspect}"
	end

	def intersect?(other)
		case other
		when ::Array
			@__value__.intersect?(other)
		when Literal::Array
			@__value__.intersect?(other.__value__)
		else
			raise ArgumentError.new("Cannot perform `intersect?` with #{other.class.name}.")
		end
	end

	def intersection(*values)
		values.map! do |value|
			case value
			when Literal::Array
				value.__value__
			else
				value
			end
		end

		__with__(@__value__.intersection(*values))
	end

	def	join(...)
		@__value__.join(...)
	end

	def keep_if(...)
		return_value = @__value__.keep_if(...)
		case return_value
		when Array
			self
		else
			return_value
		end
	end

	def last(...)
		@__value__.last(...)
	end

	def length(...)
		@__value__.length(...)
	end

	def map(type, &block)
		my_type = @__type__
		transform_type = Literal::Transforms.dig(my_type, block)

		if transform_type && Literal.subtype?(transform_type, my_type)
			Literal::Array.allocate.__initialize_without_check__(
				@__value__.map(&block),
				type:,
			)
		else
			Literal::Array.new(@__value__.map(&block), type:)
		end
	end

	alias_method :collect, :map

	# TODO: we can make this faster
	def map!(&)
		new_array = map(@__type__, &)
		@__value__ = new_array.__value__
		self
	end

	alias_method :collect!, :map!

	def sum(...)
		@__value__.sum(...)
	end

	def max(n = nil, &)
		if n
			__with__(@__value__.max(n, &))
		else
			@__value__.max(&)
		end
	end

	def min(n = nil, &)
		if n
			__with__(@__value__.min(n, &))
		else
			@__value__.min(&)
		end
	end

	def minmax(...)
		__with__(@__value__.minmax(...))
	end

	def narrow(type)
		unless Literal.subtype?(type, @__type__)
			raise ArgumentError.new("Cannot narrow #{@__type__} to #{type}")
		end

		if __type__ != type
			@__value__.each do |item|
				Literal.check(item, type) do |c|
					c.fill_receiver(receiver: self, method: "#narrow")
				end
			end
		end

		Literal::Array.allocate.__initialize_without_check__(
			@__value__,
			type:,
		)
	end

	def one?(...)
		@__value__.one?(...)
	end

	def pack(...)
		@__value__.pack(...)
	end

	def pop(...)
		@__value__.pop(...)
	end

	def product(*others, &)
		if block_given?
			@__value__.product(
				*others.map do |other|
					case other
					when Array
						other
					when Literal::Array
						other.__value__
					end
				end, &
			)

			self
		elsif others.all?(Literal::Array)
			tuple_type = Literal::Tuple(
				@__type__,
				*others.map(&:__type__)
			)

			values = @__value__.product(*others.map(&:__value__)).map do |tuple_values|
				tuple_type.new(*tuple_values)
			end

			Literal::Array(tuple_type).new(*values)
		else
			@__value__.product(*others)
		end
	end

	def push(*value)
		Literal.check(value, _Array(@__type__)) do |c|
			c.fill_receiver(receiver: self, method: "#push")
		end

		@__value__.push(*value)
		self
	end

	alias_method :append, :push

	def reject(...)
		__with__(@__value__.reject(...))
	end

	def reject!(...)
		@__value__.reject!(...)
		self
	end

	def replace(value)
		case value
		when Array
			Literal.check(value, _Array(@__type__)) do |c|
				c.fill_receiver(receiver: self, method: "#replace")
			end

			@__value__.replace(value)
		when Literal::Array(@__type__)
			@__value__.replace(value.__value__)
		when Literal::Array
			raise Literal::TypeError.new(
				context: Literal::TypeError::Context.new(expected: @__type__, actual: value.__type__)
			)
		else
			raise ArgumentError.new("#replace expects Array argument")
		end

		self
	end

	def reverse(...)
		__with__(@__value__.reverse(...))
	end

	alias_method :initialize_copy, :replace

	def reverse_each(...)
		return_value = @__value__.reverse_each(...)
		(return_value.class == Enumerator) ? return_value : self
  end

	def reverse!
		@__value__.reverse!
		self
	end

	def rotate(...)
		__with__(@__value__.rotate(...))
	end

	def rotate!(...)
		@__value__.rotate!(...)
		self
	end

	def sample(...)
		@__value__.sample(...)
	end

	def select(...)
		__with__(@__value__.select(...))
	end

	def select!(...)
		@__value__.select!(...)
		self
	end

	def shift(...)
		@__value__.shift(...)
	end

	def shuffle(...)
		__with__(@__value__.shuffle(...))
	end

	def shuffle!(...)
		@__value__.shuffle!(...)
		self
	end

	def size(...)
		@__value__.size(...)
	end

	def sort(...)
		__with__(@__value__.sort(...))
	end

	def sort!(...)
		@__value__.sort!(...)
		self
	end

	def sort_by!(...)
		@__value__.sort_by!(...)
		self
	end

	def take(...)
		__with__(@__value__.take(...))
	end

	def take_while(...)
		__with__(@__value__.take_while(...))
	end

	def transpose
		case @__type__
		when Literal::Tuple::Generic
			tuple_types = @__type__.types
			new_array_types = tuple_types.map { |t| Literal::Array(t) }

			Literal::Tuple(*new_array_types).new(
				*new_array_types.each_with_index.map do |t, i|
					t.new(
						*@__value__.map { |it| it[i] }
					)
				end
			)
		when Literal::Array::Generic
			__with__(
				@__value__.map(&:to_a).transpose.map! { |it| @__type__.new(*it) }
			)
		else
			@__value__.transpose
		end
	end

	def to_a
		@__value__.dup
	end

	alias_method :to_ary, :to_a

	def to_s
		@__value__.to_s
	end

	def uniq
		__with__(@__value__.uniq)
	end

	def uniq!(...)
		@__value__.uniq!(...) ? self : nil
	end

	def unshift(value)
		Literal.check(value, @__type__) do |c|
			c.fill_receiver(receiver: self, method: "#unshift")
		end

		@__value__.unshift(value)
		self
	end

	alias_method :prepend, :unshift

	def values_at(*indexes)
		unless @__type__ === nil
			max_value = length - 1
			min_value = -length

			indexes.each do |index|
				case index
				when Integer
					if index < min_value || index > max_value
						raise IndexError.new("index #{index} out of range")
					end
				when Range
					if index.begin < min_value || index.end > max_value
						raise IndexError.new("index #{index} out of range")
					end
				else
					raise ArgumentError.new("Invalid index: #{index.inspect}")
				end
			end
		end

		__with__(
			@__value__.values_at(*indexes)
		)
	end

	def |(other)
		case other
		when ::Array
			Literal.check(other, _Array(@__type__)) do |c|
				c.fill_receiver(receiver: self, method: "#|")
			end

			__with__(@__value__ | other)
		when Literal::Array(@__type__)
			__with__(@__value__ | other.__value__)
		when Literal::Array
			raise Literal::TypeError.new(
				context: Literal::TypeError::Context.new(
					expected: Literal::Array(@__type__),
					actual: other
				)
			)
		else
			raise ArgumentError.new("Cannot perform `|` with #{other.class.name}.")
		end
	end

	def fetch(...)
		@__value__.fetch(...)
	end

	def zip(*others)
		other_types = others.map do |other|
			case other
			when Literal::Array
				other.__type__
			when Array
				_Any?
			else
				raise ArgumentError
			end
		end

		tuple = Literal::Tuple(
			@__type__,
			*other_types
		)

		my_length = length
		max_length = [my_length, *others.map(&:length)].max

		# Check we match the max length or our type is nilable
		unless my_length == max_length || @__type__ === nil
			raise ArgumentError.new(<<~MESSAGE)
				The literal array could not be zipped becuase its type is not nilable and it has fewer items than the maximum number of items in the other arrays.

				You can either make the type of this array nilable, or add more items so its length matches the others.

				#{inspect}
			MESSAGE
		end

		# Check others match the max length or their types is nilable
		others.each_with_index do |other, index|
			unless other.length == max_length || other_types[index] === nil
				raise ArgumentError.new(<<~MESSAGE)
					The literal array could not be zipped becuase its type is not nilable and it has fewer items than the maximum number of items in the other arrays.

					You can either make the type of this array nilable, or add more items so its length matches the others.

					#{inspect}
				MESSAGE
			end
		end

		i = 0

		if block_given?
			while i < max_length
				yield tuple.new(
					@__value__[i],
					*others.map { |it| it[i] }
				)
				i += 1
			end

			nil
		else
			result_value = []

			while i < max_length
				result_value << tuple.new(
					@__value__[i],
					*others.map { |it| it[i] }
				)
				i += 1
			end

			__with__(result_value)
		end
	end
end
