# frozen_string_literal: true

class Literal::Enum
	extend Literal::Properties

	class << self
		include Enumerable

		attr_reader :members

		def values = @values.keys
		def names = @names

		def prop(name, type, kind = :keyword, reader: :public, predicate: false, default: nil)
			super(name, type, kind, reader:, writer: false, predicate:, default:)
		end

		def inherited(subclass)
			subclass.instance_exec do
				@values = {}
				@members = []
				@indexes_definitions = {}
				@indexes = {}
				@names = {}
			end

			if subclass.name && RUBY_ENGINE != "truffleruby"
				TracePoint.trace(:end) do |tp|
					if tp.self == subclass
						tp.self.__after_defined__
						tp.disable
					end
				end
			end
		end

		def position_of(member)
			coerce(member).__position__
		end

		def at_position(n)
			@members[n]
		end

		def index(name, type, unique: true, &block)
			@indexes_definitions[name] = [type, unique, block || name.to_proc]
		end

		def where(**kwargs)
			unless kwargs.length == 1
				raise ArgumentError.new("You can only specify one index when using `where`.")
			end

			key, value = kwargs.first

			types = @indexes_definitions.fetch(key)
			type = types.first
			Literal.check(value, type) { |c| raise NotImplementedError }

			@indexes.fetch(key)[value]
		end

		def find_by(**kwargs)
			unless kwargs.length == 1
				raise ArgumentError.new("You can only specify one index when using `where`.")
			end

			key, value = kwargs.first

			unless @indexes_definitions.fetch(key)[1]
				raise ArgumentError.new("You can only use `find_by` on unique indexes.")
			end

			type = @indexes_definitions.fetch(key)[0]
			Literal.check(value, type)

			@indexes.fetch(key)[value]&.first
		end

		def _load(data)
			self[Marshal.load(data)]
		end

		def const_added(name)
			raise ArgumentError if frozen?
			object = const_get(name)

			if self === object
				@names[object] = name
				predicate_name = name.to_s.gsub(/(?<=[A-Z])(?=[A-Z][a-z])|(?<=[a-z\d])(?=[A-Z])/, "_").downcase
				define_method("#{predicate_name}?") { self == object }
				object.freeze
			end
		end

		def new(*args, **kwargs, &block)
			raise ArgumentError if frozen?

			new_object = super(*args, **kwargs, &nil)

			if @values.key?(new_object.value)
				raise ArgumentError.new("The value #{new_object.value} is already used by #{@values[new_object.value].name}.")
			end

			@values[new_object.value] = new_object

			new_object.instance_variable_set(:@__position__, @members.length)

			@members << new_object

			new_object.instance_exec(&block) if block

			new_object
		end

		def __after_defined__
			raise ArgumentError if frozen?

			if RUBY_VERSION < "3.2"
				constants(false).each { |name| const_added(name) }
			end

			@indexes_definitions.each do |name, (type, unique, block)|
				index = @members.group_by(&block).freeze

				index.each do |key, values|
					Literal.check(key, type)

					if unique && values.size > 1
						raise ArgumentError.new("The index #{name} is not unique.")
					end
				end

				@indexes[name] = index
			end

			@values.freeze
			@members.freeze
			freeze
		end

		def each
			@members.each { |member| yield(member) }
		end

		def each_value(&)
			@values.each_key(&)
		end

		def [](value)
			@values[value]
		end

		alias_method :cast, :[]

		def fetch(...)
			@values.fetch(...)
		end

		def coerce(value)
			case value
			when self
				value
			when Symbol
				self[value] || begin
					const_get(value)
				rescue NameError
					raise ArgumentError.new(
						"Can't coerce #{value.inspect} into a #{inspect}."
					)
				end
			else
				self[value] || raise(
					ArgumentError.new(
						"Can't coerce #{value.inspect} into a #{inspect}."
					)
				)
			end
		end

		def to_proc
			method(:coerce).to_proc
		end

		def to_h(&)
			if block_given?
				@members.to_h(&)
			else
				@members.to_h { |it| [it, it.value] }
			end
		end
	end

	def name
		klass = self.class
		"#{klass.name}::#{klass.names[self]}"
	end

	alias_method :inspect, :name

	def to_sym
		self.class.names[self]
	end

	def to_s
		to_sym.to_s
	end

	def deconstruct
		[@value]
	end

	def deconstruct_keys(keys)
		h = to_h
		keys ? h.slice(*keys) : h
	end

	def _dump(level)
		Marshal.dump(@value)
	end

	def <=>(other)
		case other
		when self.class
			@__position__ <=> other.__position__
		else
			raise ArgumentError.new("Can't compare instances of #{other.class} to instances of #{self.class}")
		end
	end

	def succ
		self.class.members[@__position__ + 1]
	end

	def pred
		if @__position__ <= 0
			nil
		else
			self.class.members[@__position__ - 1]
		end
	end

	attr_reader :__position__
end
