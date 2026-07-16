# frozen_string_literal: true

module Literal::Properties
	include Literal::Types

	module DocString
		# @!method initialize(...)
	end

	def self.extended(base)
		super
		base.include(DocString)
		base.include(base.__send__(:__literal_extension__))
	end

	def prop?(name, type, kind = :keyword, reader: false, writer: false, predicate: false, description: nil, &coercion)
		prop(name, _Union(type, Literal::Undefined), kind, reader:, writer:, predicate:, default: Literal::Undefined, description:, &coercion)
	end

	def prop(name, type, kind = :keyword, reader: false, writer: false, predicate: false, default: nil, description: nil, &coercion)
		if default && !(Proc === default || default.frozen?)
			raise Literal::ArgumentError.new("The default must be a frozen object or a Proc.")
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
		end
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
		__literal_extension__.module_eval(code)
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
		literal_properties.generate_initializer(buffer)
		literal_properties.generate_to_h(buffer)
		new_property.generate_writer_method(buffer) if new_property.writer
		new_property.generate_reader_method(buffer) if new_property.reader
		new_property.generate_predicate_method(buffer) if new_property.predicate
		buffer
	end
end
