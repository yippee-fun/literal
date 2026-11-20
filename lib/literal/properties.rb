# frozen_string_literal: true

require "monitor"

module Literal::Properties
	include Literal::Types

	NO_CHECKS = [].freeze

	# Shapes a cache has derived facts from — a serialization context dispatching
	# on them. Facts about a type can reach the properties of any shape it refers
	# to, so a prop added to one of these advances the generation, and caches
	# hold their entries only within a generation.
	# By identity, and weak on every engine, so ad-hoc shapes can be collected.
	OBSERVED = ObjectSpace::WeakMap.new
	@generation = 0
	@generation_mutex = Mutex.new

	def self.generation
		@generation
	end

	def self.observe(shape)
		@generation_mutex.synchronize { OBSERVED[shape] = true }
	end

	def self.changed(shape)
		@generation_mutex.synchronize { @generation += 1 if OBSERVED.key?(shape) }
	end

	module DocString
		# @!method initialize(...)
	end

	def self.extended(base)
		super
		base.include(Literal::Coercions)
		base.include(DocString)
		base.include(Literal::Checks::Enforced)
		base.include(base.__send__(:__literal_extension__))
		base.__send__(:__literal_watch_first_instance__)
	end

	def inherited(subclass)
		super
		subclass.__send__(:__literal_watch_first_instance__)
	end

	# The short form of `checks`: one predicate, one message, filed against
	# `prop` — or against the value as a whole when `prop` is omitted. The
	# block's keyword parameters name the properties it reads, exactly as in
	# `checks`; an anonymous block — a bare `it`, or a Symbol proc
	# (`check(:count, "…", &:positive?)`) — reads the property the failure is
	# filed against. The message's `%{}` slots fill from the reads. A property
	# named after a reserved word is only spellable as a keyword, and its value
	# only readable through the binding:
	#
	#   check(:min, "must not be negative") { !it.negative? }
	#   check(:max, "must be greater than %{min}") { |max:, min:| max > min }
	#   check("must span something") { |min:, max:| min < max }
	#   check(:end, "must be after %{begin}") { |begin:, end:|
	#     binding.local_variable_get(:end) > binding.local_variable_get(:begin)
	#   }
	#
	# Each is the same as a `checks` block that adds the message unless the
	# predicate holds.
	def check(prop = nil, message, &block)
		raise Literal::ArgumentError.new("check requires a block") unless block

		__literal_add_check__(Literal::Checks::Check.new(owner: self, prop:, message:, block:))
	end

	# Declare a check. The block takes a reporter first, then the properties it
	# reads as keywords — handed values, to judge, never to mutate — and calls
	# `add` with the property and message, or the message alone for the value
	# as a whole. Declare as many as the shape needs; a subclass adds to its
	# parent's. Checks are independent: each runs once its reads hold their
	# types, whatever the others found.
	#
	#   checks do |errors, min:, max:|
	#     errors.add(:min, "must not be greater than max (#{max})") if min > max
	#     errors.add("must span something") if min == max
	#   end
	def checks(&block)
		raise Literal::ArgumentError.new("checks requires a block") unless block

		__literal_add_check__(Literal::Checks::Check.new(owner: self, block:, reporting: true))
	end

	private def __literal_add_check__(check)
		if frozen?
			raise Literal::ArgumentError.new(
				"Cannot declare checks on #{self}, because it is frozen."
			)
		end

		# As `prop` refuses: a check declared later would leave the subclass less
		# constrained than its parent while still passing as it.
		if (inheritor = subclasses.first)
			raise Literal::ArgumentError.new(
				"Cannot declare checks on #{self}, because #{inheritor} has already inherited them."
			)
		end

		# Only a shape that knows its instances can judge them against a new check.
		if @__literal_used__ && !__literal_existing_instances__
			raise Literal::ArgumentError.new(
				"Cannot declare checks on #{self}, because it already has instances."
			)
		end

		# Before the check installs, or a rescued failure would leave it live
		# behind an instance that breaks it.
		__literal_check_existing_instances__([check])

		__literal_set_checks__([*literal_checks, check].freeze)
		__literal_emit_checked_methods__([check])

		check
	end

	# The only way the checks change. The per-property table is derived
	# from them, so it resets here and nowhere else can forget to.
	private def __literal_set_checks__(checks)
		@literal_checks = checks
		@literal_checks_for = nil
	end

	# A new check must hold of every instance that already exists, or an
	# unsound one would sit behind the invariant nested checking trusts.
	private def __literal_check_existing_instances__(checks)
		instances = __literal_existing_instances__
		return unless instances

		properties = literal_properties

		instances.each do |instance|
			errors = Literal::Checks::Collector.new

			checks.each do |check|
				check.run(self, errors) { |name| Literal::INSTANCE_VARIABLE_GET.bind_call(instance, properties[name].__ivar__) }
			end

			next unless errors.any?

			Literal::CheckError.raise_trimmed(shape: self, errors: errors.to_errors)
		end
	end

	# The instances that already exist when a check is declared, or nil for a
	# shape that cannot know its own — a plain Data or Struct built mid-class-
	# body is untrackable. Literal::Enum answers its members.
	private def __literal_existing_instances__
		nil
	end

	# The initializer only runs checks when the shape has them, so the first
	# check has to re-emit it; the writers of the properties these checks read
	# are re-emitted for the same reason.
	private def __literal_emit_checked_methods__(checks)
		__define_literal_methods__(nil)

		checks.flat_map(&:reads).uniq.each do |name|
			property = literal_properties[name]
			__define_literal_methods__(property) if property.writer
		end

		include(__literal_extension__)
	end

	# In declaration order: inherited first, then this shape's own. Resolved
	# through the superclass like literal_properties, not copied by an
	# inherited hook — a hook is silently lost when a class overrides
	# `inherited` without calling super.
	def literal_checks
		return @literal_checks if defined?(@literal_checks)

		inherited = (Literal::Properties === superclass) ? superclass.literal_checks : NO_CHECKS

		# A frozen class can still be asked, it just cannot cache. Memoizing is
		# safe for the same reason `check` refuses once a subclass exists: an
		# ancestor's answer can never change after this class could read it.
		return inherited if frozen?

		@literal_checks = inherited
	end

	# The checks whose outcome depends on one property — what its writer
	# enforces on every assignment.
	def literal_checks_for(name)
		table = (@literal_checks_for ||= {})
		# Complete once the shape is finished, so it is only ever read.
		return table.fetch(name, NO_CHECKS) if table.frozen?

		table[name] ||= __literal_checks_for__(name)
	end

	private def __literal_checks_for__(name)
		literal_checks.select { |check| check.depends_on?(name) }.freeze
	end

	private def __literal_checked_property__?(name)
		literal_checks_for(name).any?
	end

	# Forwarded, so each class's `prop` decides which options it takes and their defaults.
	def prop?(name, type, kind = :keyword, **options, &coercion)
		# The union admitting Literal::Undefined is what makes the property
		# optional — see Literal::Property#undefinable? — so there's no default.
		if options.key?(:default)
			raise Literal::ArgumentError.new("The optional property #{name.inspect} can't have a default.")
		end

		prop(name, _Union(type, Literal::Undefined), kind, **options, &coercion)
	end

	def prop(name, type, kind = :keyword, reader: false, writer: false, predicate: false, default: nil, description: nil, &coercion)
		unless Literal::Property.valid_name?(name)
			raise Literal::ArgumentError.new("The property name #{name.inspect} must be a Symbol that Ruby accepts as a local variable name.")
		end

		seal = nil

		# A block built from a Literal::Coercion or Literal::Seal carries its
		# pipeline structure, which splits into the property's two slots.
		if coercion.respond_to?(:__literal_pipeline__)
			pipeline = coercion.__literal_pipeline__
			coercion = pipeline.coercion_proc
			seal = pipeline.seal_proc
		end

		if default && !(Proc === default || Literal::FROZEN.bind_call(default))
			raise Literal::ArgumentError.new("The default must be a frozen object or a Proc.")
		end

		if nil != default && !(Proc === default) && !coercion && !seal && !(Literal::Types::DeferredType === type) && !(type === default)
			raise Literal::ArgumentError.new("The default for #{name.inspect} must match its type.")
		end

		unless Literal::Property::VISIBILITY_OPTIONS.include?(reader)
			raise Literal::ArgumentError.new("The reader must be one of #{Literal::Property::VISIBILITY_OPTIONS.map(&:inspect).join(', ')}.")
		end

		unless Literal::Property::VISIBILITY_OPTIONS.include?(writer)
			raise Literal::ArgumentError.new("The writer must be one of #{Literal::Property::VISIBILITY_OPTIONS.map(&:inspect).join(', ')}.")
		end

		unless Literal::Property::VISIBILITY_OPTIONS.include?(predicate)
			raise Literal::ArgumentError.new("The predicate must be one of #{Literal::Property::VISIBILITY_OPTIONS.map(&:inspect).join(', ')}.")
		end

		{ reader: [reader, name], predicate: [predicate, :"#{name.name}?"] }.each do |option, (visibility, method_name)|
			next unless visibility && (replaced = __literal_relied_on__(method_name))

			raise Literal::ArgumentError.new(
				"The #{option} for #{name.inspect} would replace #{replaced}, which Literal relies on. Declare the property with `#{option}: false`."
			)
		end

		unless Literal::Property::KIND_OPTIONS.include?(kind)
			raise Literal::ArgumentError.new("The kind must be one of #{Literal::Property::KIND_OPTIONS.map(&:inspect).join(', ')}.")
		end

		unless description.nil? || String === description
			raise Literal::ArgumentError.new("The description must be a String or nil.")
		end

		if frozen?
			raise Literal::ArgumentError.new("Cannot define #{name.inspect} on #{self}, because it is frozen.")
		end

		queue = subclasses
		until queue.empty?
			subclass = queue.shift

			if subclass.instance_variable_defined?(:@literal_properties)
				raise Literal::ArgumentError.new("Cannot define #{name.inspect} on #{self}, because #{subclass} has already inherited its properties.")
			end

			queue.concat(subclass.subclasses)
		end

		if Literal::Properties === superclass && (inherited_property = superclass.literal_properties[name])
			unless kind == inherited_property.kind
				raise Literal::ArgumentError.new("The kind for #{name.inspect} must match the inherited kind #{inherited_property.kind.inspect}.")
			end

			{ reader:, writer:, predicate: }.each do |option, visibility|
				inherited_visibility = inherited_property.__send__(option)

				if Literal::Property::VISIBILITY_ORDER[visibility] < Literal::Property::VISIBILITY_ORDER[inherited_visibility]
					raise Literal::ArgumentError.new("The #{option} for #{name.inspect} must be at least as visible as the inherited #{option}, which is #{inherited_visibility.inspect}.")
				end
			end

			inherited_type = inherited_property.type

			unless Literal::Types::DeferredType === type || Literal::Types::DeferredType === inherited_type || Literal.subtype?(type, inherited_type)
				raise Literal::ArgumentError.new("The type for #{name.inspect} must be a subtype of the inherited type #{inherited_type.inspect}.")
			end
		end

		property = __literal_property_class__.new(
			name:,
			type:,
			kind:,
			reader:,
			writer:,
			predicate:,
			default:,
			description:,
			coercion:,
			seal:,
		)

		__literal_add_property__(property)

		name
	end

	def freeze
		return super if frozen?

		__literal_finish__
		super
	end

	# Closed as if it had an instance, with everything derived from its schema
	# and checks computed, so building and reading it never writes to the class
	# again.
	private def __literal_finish__
		__literal_define_schema_methods__
		__literal_used__
		__literal_unwatch__

		unless @literal_checks_for&.frozen?
			@literal_checks_for = literal_properties.to_h { |property| [property.name, __literal_checks_for__(property.name)] }.freeze
		end
	end

	# For Literal.make_shareable, once the shape is frozen. Its ancestors are
	# shared too, because the methods they generated read their own schemas, but
	# not frozen: having a subclass, they can't change anyway.
	private def __literal_make_shareable__
		shape = self

		while Literal::Properties === shape
			shape.__send__(:__literal_share__)
			shape = shape.superclass
		end
	end

	private def __literal_share__
		__literal_finish__

		seen = {}.compare_by_identity
		literal_properties.each { |property| __literal_materialize__(property.type, seen) }

		return unless defined?(Ractor)

		literal_properties.each do |property|
			__literal_make_proc_shareable__(property.coercion) if property.coercion
			__literal_make_proc_shareable__(property.seal) if property.seal
		end

		Ractor.make_shareable(literal_properties)
		Ractor.make_shareable(literal_checks)
		Ractor.make_shareable(@literal_checks_for)
	end

	# Ruby only makes a proc shareable once what it captures is, and won't reach
	# in to make it so. Literal's own procs capture other procs and objects — a
	# composition's stages, a collection's coercer — so those go first.
	private def __literal_make_proc_shareable__(proc)
		# A shared proc has no binding to read, and a superclass's schema holds
		# the same procs as its subclass's.
		return proc if Ractor.shareable?(proc)

		if proc.source_location&.first&.start_with?(LIBRARY)
			binding = proc.binding

			binding.local_variables.each do |name|
				case (captured = binding.local_variable_get(name))
				in ::Proc
					__literal_make_proc_shareable__(captured)
				else
					Ractor.make_shareable(captured)
				end
			end
		end

		Ractor.make_shareable(proc)
	end

	# Walking a type's children materializes the deferred types among them, so a
	# frozen one never has to run its block again. Shapes are left to be made
	# shareable themselves.
	private def __literal_materialize__(type, seen)
		case type
		in Module
			nil
		in Literal::Type unless seen.key?(type)
			seen[type] = true
			type.literal_child_types { |child| __literal_materialize__(child, seen) }
		else
			nil
		end
	end

	def slice(*names)
		properties = literal_properties

		names.each do |name|
			properties[name] || raise(NameError.new("unknown property: #{name.inspect} for #{self}"))
		end

		context = Literal::SubtypeContext.new

		# A shape extending Literal::Properties directly can slice down to its plain superclass.
		base = self
		while Literal::Properties === base && !base.literal_properties.all? { |property| names.include?(property.name) && Literal.subtype?(properties[property.name].type, property.type, context:) }
			base = base.superclass
		end

		base_properties = (Literal::Properties === base) ? base.literal_properties : Literal::Properties::Schema.new
		sliced = properties.select { |property| names.include?(property.name) && !property.equal?(base_properties[property.name]) }
		origin_name = name

		Class.new(base) do
			extend Literal::Properties unless Literal::Properties === self

			if origin_name && respond_to?(:set_temporary_name)
				set_temporary_name "#{origin_name}.slice(#{names.map(&:inspect).join(', ')})"
			end

			__literal_copy_properties__ do
				sliced.each { |property| __literal_add_property__(property) }
			end
		end.tap { |projection| projection.__send__(:__literal_slice_checks__, self, names) }
	end

	# A projection keeps the checks whose every property survives the slice.
	# Inheritance alone would answer with the walked-to ancestor's, which is
	# arbitrary — it depends on how many properties the slice kept.
	protected def __literal_slice_checks__(origin, names)
		kept = origin.literal_checks.select { |check| check.applies_to?(names) }

		__literal_set_checks__(kept.freeze)

		# Every kept check, not just the last: the class body emitted the
		# initializer and writers before this ran, knowing none of them.
		return if kept.empty?

		__literal_emit_checked_methods__(kept)
	end

	def literal_properties
		return @literal_properties if defined?(@literal_properties)

		if Literal::Properties === superclass
			@literal_properties = superclass.literal_properties.dup
		else
			@literal_properties = Literal::Properties::Schema.new
		end
	end

	private def __literal_property_class__
		Literal::Property
	end

	LIBRARY = "#{__dir__}/".freeze

	# The method of this shape's instances that Literal relies on and that a
	# reader or predicate of this name would replace — a schema-wide method the
	# shape generates, or one defined by Literal's own classes and modules —
	# or nil. Methods from Ruby itself, the application, or an inherited
	# property's accessors are the shape's to replace.
	private def __literal_relied_on__(method_name)
		return "the generated ##{method_name.name}" if __literal_schema_methods__.include?(method_name)
		return unless method_defined?(method_name) || private_method_defined?(method_name)

		owner = instance_method(method_name).owner
		file, = owner.name && Object.const_source_location(owner.name)

		"#{owner.name}##{method_name.name}" if file&.start_with?(LIBRARY)
	rescue NameError
		# A temporary name, which a generated module carries.
		nil
	end

	# Marks the shape used when `new` first makes one, then steps out of the
	# way, so later instances cost nothing more. Included, not prepended, so
	# the shape's own `new` — or its own `private_class_method :new` — still
	# comes first, and as private as the `new` it stands in front of.
	private def __literal_watch_first_instance__
		watch = Module.new
		private_new = singleton_class.private_method_defined?(:new)

		# Compiled from a string, because a method defined with a block can't be
		# called from another Ractor.
		watch.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
			def new(*args, **kwargs, &block)
				instance = __literal_constructing__ { super(*args, **kwargs, &block) }
				__literal_unwatch__
				instance
			end
		RUBY

		watch.__send__(:private, :new) if private_new
		singleton_class.include(watch)
		@__literal_watch__ = watch
	end

	# A shape is closed with its ancestors, so none of them needs to watch.
	private def __literal_unwatch__
		SCHEMA_METHODS_LOCK.synchronize do
			shape = self

			while Literal::Properties === shape
				watch = shape.instance_variable_get(:@__literal_watch__)

				if watch && (watch.method_defined?(:new, false) || watch.private_method_defined?(:new, false))
					watch.remove_method(:new)
				end

				shape = shape.superclass
			end
		end
	end

	# A shape's properties are fixed while an instance is under construction,
	# so none of its slots can be missing, and for good once it has one. So are
	# its ancestors', which it holds too. A failed construction reopens them
	# unless another is under way or has finished.
	private def __literal_constructing__
		return yield if true == @__literal_used__

		unless Literal.main_ractor?
			raise Ractor::IsolationError.new("#{self} can't be built outside the main Ractor until it is passed to Literal.make_shareable.")
		end

		__literal_count_constructions__(1)
		finished = false

		begin
			# Once the shape is closed, but before any instance exists, so none can
			# reach a stand-in from another Ractor, however it was built.
			shape = self

			while Literal::Properties === shape
				shape.__send__(:__literal_define_schema_methods__)
				shape = shape.superclass
			end

			instance = yield
			finished = true
		ensure
			__literal_count_constructions__(-1) unless finished
		end

		__literal_used__
		instance
	end

	private def __literal_used__
		return if true == @__literal_used__

		__literal_each_open_shape__ { |shape| shape.instance_variable_set(:@__literal_used__, true) }
	end

	private def __literal_count_constructions__(change)
		__literal_each_open_shape__ do |shape|
			count = (shape.instance_variable_get(:@__literal_used__) || 0) + change
			shape.instance_variable_set(:@__literal_used__, count.zero? ? false : count)
		end
	end

	# Each shape up from this one until one with an instance, under its own lock.
	private def __literal_each_open_shape__
		shape = self

		while Literal::Properties === shape
			closed = shape.__send__(:__literal_lock__).synchronize do
				next true if true == shape.instance_variable_get(:@__literal_used__)

				yield shape unless shape.frozen?
				false
			end

			break if closed

			shape = shape.superclass
		end
	end

	# Guards whether the shape has instances. Its own, not one for every shape,
	# so code a declaration runs, like a type's ===, can wait on another shape's
	# construction. A frozen shape can't change.
	private def __literal_lock__
		@__literal_lock__ || SCHEMA_METHODS_LOCK.synchronize do
			frozen? ? SCHEMA_METHODS_LOCK : (@__literal_lock__ ||= Monitor.new)
		end
	end

	# Under the shape's lock, which a construction takes to close it, so the
	# property either comes before every instance or is refused.
	private def __literal_add_property__(property)
		__literal_lock__.synchronize do
			# An instance made or under way would be missing it.
			if @__literal_used__
				raise Literal::ArgumentError.new("Cannot define #{property.name.inspect} on #{self}, because it already has instances.")
			end

			schema = literal_properties

			# A keyword can't break the signature.
			unless :keyword == property.kind || @__literal_copying_properties__
				schema.check_signature(schema.sorted_with(property))
			end

			schema << property
			# After the change, so an entry labelled with the new generation was
			# computed from it.
			Literal::Properties.changed(self)
			__define_literal_methods__(property)
			include(__literal_extension__)
		end
	end

	# Properties copied from a sound schema may pass through orders that aren't,
	# so the signature is judged once they are all in.
	private def __literal_copy_properties__
		@__literal_copying_properties__ = true
		yield
		literal_properties.check_signature
	ensure
		@__literal_copying_properties__ = false
	end

	private def __define_literal_methods__(new_property)
		if new_property
			code = __generate_literal_property_methods__(new_property, +"# frozen_string_literal: true\n")
			__literal_silence_redefinitions__(new_property)
			# An explicit path, so every engine attributes these frames to Literal.
			__literal_extension__.module_eval(code, __FILE__, __LINE__)
		end

		__literal_defer_schema_methods__
		# A check can reach a shape with instances, whose later ones skip generating.
		__literal_define_schema_methods__ if @__literal_used__
	end

	SCHEMA_METHODS = [:initialize, :to_h, :to_hash].freeze
	SCHEMA_METHODS_LOCK = Monitor.new

	private def __literal_schema_methods__
		SCHEMA_METHODS
	end

	# Generating the schema-wide methods on every prop would make defining a
	# shape quadratic in its size, so each change replaces them with stand-ins.
	# The first call to one — usually the first instance — generates the real
	# methods and hands over to them.
	private def __literal_defer_schema_methods__
		return if @__literal_schema_methods_deferred__

		@__literal_schema_methods_deferred__ = true

		shape = self
		extension = __literal_extension__

		__literal_schema_methods__.each do |name|
			extension.alias_method(name, name) if extension.method_defined?(name, false) || extension.private_method_defined?(name, false)
			extension.define_method(name) do |*args, **kwargs, &block|
				shape.__send__(:__literal_define_schema_methods__)
				extension.instance_method(name).bind_call(self, *args, **kwargs, &block)
			end
		end
	end

	private def __literal_define_schema_methods__
		return unless @__literal_schema_methods_deferred__

		# A second thread reaching a stand-in waits here, then finds the real
		# methods in place. Re-entrant, because generating can materialize a
		# deferred type whose block defines another shape. The shape's own lock,
		# since generating can run user code that waits on another shape's.
		__literal_lock__.synchronize do
			next unless @__literal_schema_methods_deferred__

			code = __generate_literal_methods__

			extension = __literal_extension__
			__literal_schema_methods__.each { |name| extension.alias_method(name, name) }
			extension.module_eval(code, __FILE__, __LINE__)

			@__literal_schema_methods_deferred__ = false
		end
	end

	# Re-emitting a property's methods — a writer picking up a new check —
	# would warn under `-w`. A method aliased to itself is marked, and Ruby stays
	# quiet when a marked method is redefined; the generated initializer, to_h,
	# hash and == silence themselves the same way inline.
	private def __literal_silence_redefinitions__(property)
		extension = __literal_extension__
		name = property.name.name

		names = []
		names << :"#{name}=" if property.writer
		names << property.name if property.reader
		names << :"#{name}?" if property.predicate

		names.each do |method_name|
			if extension.method_defined?(method_name) || extension.private_method_defined?(method_name)
				extension.alias_method(method_name, method_name)
			end
		end
	end

	private def __literal_extension__
		if defined?(@__literal_extension__)
			@__literal_extension__
		else
			properties = literal_properties.properties_index

			@__literal_extension__ = Module.new do
				# What the generated methods look their properties up in, rather than
				# through `self.class`, which a property's reader could replace.
				const_set(:PROPERTIES, properties)
				private_constant :PROPERTIES

				def initialize
					after_initialize if Literal::RESPOND_TO.bind_call(self, :after_initialize, true)
				end

				def to_h
					{}
				end

				alias to_hash to_h

				set_temporary_name "Literal::Properties(Extension)" if respond_to?(:set_temporary_name)
			end
		end
	end

	private def __generate_literal_methods__(buffer = +"")
		buffer << "# frozen_string_literal: true\n"
		literal_properties.generate_initializer(buffer, checked: literal_checks.any?)
		literal_properties.generate_to_h(buffer)
		buffer
	end

	private def __generate_literal_property_methods__(property, buffer)
		property.generate_writer_method(buffer, checked: __literal_checked_property__?(property.name)) if property.writer
		property.generate_reader_method(buffer) if property.reader
		property.generate_predicate_method(buffer) if property.predicate
		buffer
	end
end
