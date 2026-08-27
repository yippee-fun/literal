# frozen_string_literal: true

module Literal::Properties
	include Literal::Types

	NO_STIPULATIONS = [].freeze

	module DocString
		# @!method initialize(...)
	end

	def self.extended(base)
		super
		base.include(Literal::Coercions)
		base.include(DocString)
		base.include(Literal::Validatable)
		base.include(base.__send__(:__literal_extension__))
	end

	# Declare one validation stipulation. `prop` is the property a failure is
	# filed against; omit it for a failure about the value as a whole. The
	# predicate's parameter names — positional or keyword — name the properties
	# it reads, and it is handed their values — to judge, never to mutate. A
	# bare `it` reads the property the failure is filed against. A property
	# named after a reserved word is only spellable as a keyword, and its value
	# only readable through the binding:
	#
	#   stipulate(:min, "must not be negative") { !it.negative? }
	#   stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
	#   stipulate(:end, "must be after %{begin}") { |begin:, end:|
	#     binding.local_variable_get(:end) > binding.local_variable_get(:begin)
	#   }
	def stipulate(prop = nil, message, &predicate)
		raise Literal::ArgumentError.new("stipulate requires a block") unless predicate

		if frozen?
			raise Literal::ArgumentError.new(
				"Cannot declare validations on #{self}, because it is frozen."
			)
		end

		# As `prop` refuses: a rule declared later would leave the subclass less
		# constrained than its parent while still passing as it.
		if (inheritor = subclasses.first)
			raise Literal::ArgumentError.new(
				"Cannot declare validations on #{self}, because #{inheritor} has already inherited them."
			)
		end

		stipulation = Literal::Validations::Stipulation.new(owner: self, prop:, message:, predicate:)

		# Before the rule installs, or a rescued failure would leave it live
		# behind an instance that breaks it.
		__literal_check_existing_instances__([stipulation])

		__literal_set_stipulations__([*stipulations, stipulation].freeze)
		__literal_emit_validated_methods__([stipulation])

		stipulation
	end

	# The only way the stipulations change. The per-property table is derived
	# from them, so it resets here and nowhere else can forget to.
	private def __literal_set_stipulations__(stipulations)
		@stipulations = stipulations
		@stipulations_for = nil
	end

	# A new rule must hold of every instance that already exists, or an
	# invalid one would sit behind the invariant nested validation trusts.
	private def __literal_check_existing_instances__(stipulations)
		instances = __literal_existing_instances__
		return unless instances

		properties = literal_properties

		instances.each do |instance|
			errors = Literal::Validations::Collector.new

			stipulations.each do |stipulation|
				stipulation.check(errors) { |name| instance.instance_variable_get(properties[name].__ivar__) }
			end

			next unless errors.any?

			Literal::ValidationError.raise_trimmed(shape: self, errors: errors.to_errors)
		end
	end

	# The instances that already exist when a rule is declared, or nil for a
	# shape that cannot know its own — a plain Data or Struct built mid-class-
	# body is untrackable. Literal::Enum answers its members.
	private def __literal_existing_instances__
		nil
	end

	# The initializer only checks when the shape has stipulations, so the first
	# rule has to re-emit it; the writers of the properties these rules read
	# are re-emitted for the same reason.
	private def __literal_emit_validated_methods__(stipulations)
		__define_literal_methods__(nil)

		stipulations.flat_map(&:reads).uniq.each do |name|
			property = literal_properties[name]
			__define_literal_methods__(property) if property.writer
		end

		include(__literal_extension__)
	end

	# In declaration order: inherited first, then this shape's own. Resolved
	# through the superclass like literal_properties, not copied by an
	# inherited hook — a hook is silently lost when a class overrides
	# `inherited` without calling super.
	def stipulations
		return @stipulations if defined?(@stipulations)

		inherited = (Literal::Properties === superclass) ? superclass.stipulations : NO_STIPULATIONS

		# A frozen class can still be asked, it just cannot cache. Memoizing is
		# safe for the same reason `stipulate` refuses once a subclass exists:
		# an ancestor's answer can never change after this class could read it.
		return inherited if frozen?

		@stipulations = inherited
	end

	# The stipulations whose outcome depends on one property — what its writer
	# enforces on every assignment.
	def stipulations_for(name)
		return __literal_stipulations_for__(name) if frozen?

		table = (@stipulations_for ||= {})
		table[name] ||= __literal_stipulations_for__(name)
	end

	private def __literal_stipulations_for__(name)
		stipulations.select { |stipulation| stipulation.depends_on?(name) }.freeze
	end

	private def __literal_validated_property__?(name)
		stipulations_for(name).any?
	end

	# Takes exactly what `new` takes and answers a Literal::Result. A draft's
	# writers type check, so a wrong type raises as it would from `new`; for
	# input from outside, use `validate_from_props`. Accepting a draft or
	# instance here would be ambiguous for a shape whose first positional
	# property can hold one — ask it instead: `draft.validate`.
	def validate(...)
		Literal::Validations::Validator.validate(self, Literal::Draft(self).new(...))
	end

	# Every error in a Hash of props keyed by Symbol or String, including type
	# errors — the form for input from outside, where nothing may raise.
	def validate_from_props(props)
		unless Hash === props
			raise Literal::ArgumentError.new(
				"#{name || inspect}.validate_from_props takes a Hash of properties, got #{props.class}"
			)
		end

		Literal::Validations::Validator.validate(self, props)
	end

	def prop?(name, type, kind = :keyword, reader: false, writer: false, predicate: false, description: nil, &coercion)
		# The union admitting Literal::Undefined is what makes the property
		# optional — see Literal::Property#undefinable? — so there's no default.
		prop(name, _Union(type, Literal::Undefined), kind, reader:, writer:, predicate:, description:, &coercion)
	end

	def prop(name, type, kind = :keyword, reader: false, writer: false, predicate: false, default: nil, description: nil, &coercion)
		seal = nil

		# A block built from a Literal::Coercion or Literal::Seal carries its
		# pipeline structure, which splits into the property's two slots.
		if coercion.respond_to?(:__literal_pipeline__)
			pipeline = coercion.__literal_pipeline__
			coercion = pipeline.coercion_proc
			seal = pipeline.seal_proc
		end

		if default && !(Proc === default || default.frozen?)
			raise Literal::ArgumentError.new("The default must be a frozen object or a Proc.")
		end

		if !default.nil? && !(Proc === default) && !coercion && !seal && !(Literal::Types::DeferredType === type) && !(type === default)
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

		if reader && :class == name
			raise Literal::ArgumentError.new(
				"The `:class` property should not be defined as a reader because it breaks Ruby's `Object#class` method, which Literal itself depends on.",
			)
		end

		unless Literal::Property::KIND_OPTIONS.include?(kind)
			raise Literal::ArgumentError.new("The kind must be one of #{Literal::Property::KIND_OPTIONS.map(&:inspect).join(', ')}.")
		end

		unless description.nil? || String === description
			raise Literal::ArgumentError.new("The description must be a String or nil.")
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

		literal_properties << property
		__define_literal_methods__(property)
		include(__literal_extension__)

		name
	end

	def slice(*names)
		properties = literal_properties

		names.each do |name|
			properties[name] || raise(NameError.new("unknown property: #{name.inspect} for #{self}"))
		end

		context = Literal::SubtypeContext.new

		base = self
		until base.literal_properties.all? { |property| names.include?(property.name) && Literal.subtype?(properties[property.name].type, property.type, context:) }
			base = base.superclass
		end

		base_properties = base.literal_properties
		sliced = properties.select { |property| names.include?(property.name) && !property.equal?(base_properties[property.name]) }
		origin_name = name

		Class.new(base) do
			if origin_name && respond_to?(:set_temporary_name)
				set_temporary_name "#{origin_name}.slice(#{names.map(&:inspect).join(', ')})"
			end

			sliced.each do |property|
				literal_properties << property
				__define_literal_methods__(property)
				include(__literal_extension__)
			end
		end.tap { |projection| projection.__send__(:__literal_slice_stipulations__, self, names) }
	end

	# A projection keeps the stipulations whose every property survives the
	# slice. Inheritance alone would answer with the walked-to ancestor's,
	# which is arbitrary — it depends on how many properties the slice kept.
	protected def __literal_slice_stipulations__(origin, names)
		kept = origin.stipulations.select { |stipulation| stipulation.applies_to?(names) }

		__literal_set_stipulations__(kept.freeze)

		# Every kept rule, not just the last: the class body emitted the
		# initializer and writers before this ran, knowing none of them.
		return if kept.empty?

		__literal_emit_validated_methods__(kept)
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

	private def __define_literal_methods__(new_property)
		code =	__generate_literal_methods__(new_property)
		__literal_silence_redefinitions__(new_property) if new_property
		__literal_extension__.module_eval(code)
	end

	# Re-emitting a property's methods — a writer picking up a new stipulation —
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
			@__literal_extension__ = Module.new do
				def initialize
					after_initialize if respond_to?(:after_initialize, true)
				end

				def to_h
					{}
				end

				alias to_hash to_h

				set_temporary_name "Literal::Properties(Extension)" if respond_to?(:set_temporary_name)
			end
		end
	end

	private def __generate_literal_methods__(new_property, buffer = +"")
		buffer << "# frozen_string_literal: true\n"
		literal_properties.generate_initializer(buffer, validate: stipulations.any?)
		literal_properties.generate_to_h(buffer)

		# Nil when re-emitting for a new stipulation rather than a new property.
		if new_property
			new_property.generate_writer_method(buffer, validate: __literal_validated_property__?(new_property.name)) if new_property.writer
			new_property.generate_reader_method(buffer) if new_property.reader
			new_property.generate_predicate_method(buffer) if new_property.predicate
		end

		buffer
	end
end
