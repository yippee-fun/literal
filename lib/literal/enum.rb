# frozen_string_literal: true

class Literal::Enum
	extend Literal::Properties

	class << self
		include Enumerable

		attr_reader :members

		def values = @values.keys
		def names = @names

		def prop(name, type, kind = :keyword, reader: :public, predicate: false, default: nil, description: nil)
			super(name, type, kind, reader:, writer: false, predicate:, default:, description:)
		end

		def const(name, value, reader: :public, description: nil, &)
			prop(name, value, :const, reader:, default: value, description:, &)
		end

		# Members are idiomatically defined above the checks in the class body,
		# so `check` judges them before it installs.
		private def __literal_existing_instances__
			@members
		end

		def inherited(subclass)
			super

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

		# A hook for anything that knows when the class body has closed, sparing
		# the wait for the TracePoint — which never fires for an anonymous class.
		private def defined
			__after_defined__
			super if defined?(super)
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
			Literal.check(value, type)

			@indexes.fetch(key)[value]
		end

		def find_by(**kwargs)
			unless kwargs.length == 1
				raise ArgumentError.new("You can only specify one index when using `find_by`.")
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
			fetch(Marshal.load(data))
		end

		def const_added(name)
			raise ArgumentError if frozen?
			super
			object = const_get(name)

			if self === object
				snake_case = name.name.gsub(/(?<=[A-Z])(?=[A-Z][a-z])|(?<=[a-z\d])(?=[A-Z])/, "_").downcase
				predicate = :"#{snake_case}?"

				if method_defined?(predicate) || private_method_defined?(predicate)
					owner = instance_method(predicate).owner

					# Ruby has published the constant and `new` the member; neither
					# may outlive the refusal. A member built before others keeps
					# its place, as an unnamed one, so their positions hold.
					remove_const(name)

					if !@names.key?(object) && @members.last.equal?(object)
						@values.delete_if { |_, member| member.equal?(object) }
						@members.pop
					end

					raise Literal::ArgumentError.new(
						"The member #{name} can't define the predicate ##{predicate}, because it would override #{owner}##{predicate}."
					)
				end

				@names[object] ||= name
				define_method(predicate) { self == object }
				Literal::FREEZE.bind_call(object)
			end
		end

		def new(*, **, &block)
			raise ArgumentError if frozen?

			new_object = super(*, **, &nil)

			# Before the member registers, so uniqueness and the shape's checks
			# are judged on the state the block left — and a failure leaves
			# nothing behind.
			if block
				Literal::INSTANCE_EXEC.bind_call(new_object, &block)
				Literal::SEND.bind_call(new_object, :__literal_run_checks__) if literal_checks.any?
			end

			if @values.key?(new_object.value)
				raise ArgumentError.new("The value #{new_object.value} is already used by #{@values[new_object.value].name}.")
			end

			@values[new_object.value] = new_object

			Literal::INSTANCE_VARIABLE_SET.bind_call(new_object, :@Position, @members.length)

			@members << new_object

			new_object
		end

		def __after_defined__
			return if @finished
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

			@finished = true
			@values.freeze
			@members.freeze
			freeze
		end

		def each
			return enum_for(__method__) { @members.size } unless block_given?

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
				self[value] || member_named(value) || raise(
					ArgumentError.new(
						"Can't coerce #{value.inspect} into a #{inspect}."
					)
				)
			else
				self[value] || raise(
					ArgumentError.new(
						"Can't coerce #{value.inspect} into a #{inspect}."
					)
				)
			end
		end

		private def member_named(name)
			member = const_get(name)
		rescue NameError
			nil
		else
			member if @members.include?(member)
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

	include Comparable

	def name
		klass = Literal::CLASS.bind_call(self)
		"#{klass.name || klass.inspect}::#{klass.names[self]}"
	end

	alias_method :inspect, :name

	def to_sym
		Literal::CLASS.bind_call(self).names[self]
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

	def dup
		self
	end

	def clone(freeze: nil)
		case freeze
		in true | nil
			self
		in false
			raise ArgumentError.new("can't unfreeze #{Literal::CLASS.bind_call(self).inspect}")
		else
			raise ArgumentError.new("unexpected value for freeze: #{Literal::CLASS.bind_call(freeze)}")
		end
	end

	def _dump(level)
		Marshal.dump(@value)
	end

	def <=>(other)
		shape = Literal::CLASS.bind_call(self)

		case other
		when shape
			@Position <=> other.__position__ if Literal::CLASS.bind_call(other).equal?(shape)
		end
	end

	def succ
		Literal::CLASS.bind_call(self).members[@Position + 1]
	end

	def pred
		if @Position <= 0
			nil
		else
			Literal::CLASS.bind_call(self).members[@Position - 1]
		end
	end

	# Capitalized, so no property's slot can be this one.
	def __position__
		@Position
	end
end
