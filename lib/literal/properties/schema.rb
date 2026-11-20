# frozen_string_literal: true

# @api private
class Literal::Properties::Schema
	include Enumerable

	EQL_INTERFACE = Literal::Types::InterfaceType.new([:eql?])
	HASH_INTERFACE = Literal::Types::InterfaceType.new([:hash])

	def initialize(properties_index: {}, sorted_properties: [])
		@properties_index = properties_index
		@sorted_properties = sorted_properties
	end

	attr_reader :properties_index

	# The current sorted properties array. Its object identity changes if and
	# only if the schema changes — `<<` replaces the array rather than
	# mutating it, and `dup` copies it — so it can key caches of anything
	# derived from the schema, such as generated draft classes.
	def snapshot
		@sorted_properties
	end

	def [](key)
		@properties_index[key]
	end

	# Only under the lock of the shape that owns the schema.
	def <<(value)
		@properties_index[value.name] = value
		# Replacing (not mutating) the array is a contract: `snapshot`
		# relies on its identity changing with every schema change.
		@sorted_properties = sort(@properties_index)

		self
	end

	# The sorted properties this schema would have with the property added.
	def sorted_with(property)
		sort(@properties_index.merge(property.name => property))
	end

	private def sort(properties_index)
		# ruby's sort is unstable, this trick makes it stable
		n = 0
		properties_index.values.sort_by! { |it| n += 1; [it, n] }
	end

	def dup
		self.class.new(
			properties_index: @properties_index.dup,
			sorted_properties: @sorted_properties.dup,
		)
	end

	def each(&)
		@sorted_properties.each(&)
	end

	def size
		@sorted_properties.size
	end

	def empty?
		@sorted_properties.empty?
	end

	def generate_initializer(buffer = +"", checked: false)
		check_signature

		locals, property_local = initializer_locals

		buffer << "alias initialize initialize\n" \
			"def initialize("
		generate_initializer_params(buffer, locals)
		buffer << ")\n"
		generate_initializer_body(buffer, locals, property_local)
		buffer << "" \
			"rescue ::Literal::TypeError => error\n" \
			"  error.set_backtrace(::Literal::Error.trim(::Kernel.caller_locations(1)))\n" \
			"  ::Kernel.raise\n" \
			"else\n"
		generate_after_initializer(buffer)

		# After every value is assigned, after after_initialize, and after the
		# freeze a Data appends — so a check judges a finished object and cannot
		# normalize it. Emitted only when the shape has checks, so a shape without
		# them pays nothing.
		buffer << "  __literal_run_checks__\n" if checked

		buffer << "end\n"
	end

	def generate_after_initializer(buffer = +"")
		buffer << "  after_initialize if ::Literal::RESPOND_TO.bind_call(self, :after_initialize, true)\n"
	end

	def generate_to_h(buffer = +"")
		buffer << "alias to_h to_h\n"
		buffer << "def to_h\n" << "  {\n"

		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			buffer << "    " << property.name.name << ": @" << property.name.name << ",\n"
			i += 1
		end

		buffer << "  }\n" << "end\n"
		buffer << "alias to_hash to_h\n"
	end

	def generate_hash(buffer = +"")
		buffer << "alias hash hash\n" \
			"def hash\n  [::Literal::CLASS.bind_call(self),\n"

		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			value = "@#{property.name.name}"

			if promises?(property, HASH_INTERFACE)
				buffer << "  " << value << ",\n"
			else
				buffer << "  ((::Kernel === #{value} && #{value}.respond_to?(:hash)) ? #{value}.hash : ::Literal.payload_hash(#{value})),\n"
			end

			i += 1
		end

		buffer << "  ].hash\n" << "end\n"
	end

	# eql? compares values with eql?, as hash hashes them. A value whose type
	# doesn't promise a public eql? or hash, such as a BasicObject, is checked
	# for one, and goes through the payload helpers without it.
	def generate_eq(buffer = +"")
		generate_comparison(buffer, "==") { |_property, value, other| "#{value} == #{other}" }

		generate_comparison(buffer, "eql?") do |property, value, other|
			if promises?(property, EQL_INTERFACE)
				"#{value}.eql?(#{other})"
			else
				"((::Kernel === #{value} && #{value}.respond_to?(:eql?)) ? #{value}.eql?(#{other}) : ::Literal.payload_eql?(#{value}, #{other}))"
			end
		end
	end

	private def generate_comparison(buffer, operator)
		buffer << "alias " << operator << " " << operator << "\n" \
			"def " << operator << "(other)\n"
		buffer << "  return false unless ::Kernel === other && ::Literal::CLASS.bind_call(self).equal?(::Literal::CLASS.bind_call(other))\n"

		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			buffer << "  " << yield(property, "@#{property.name.name}", "::Literal::INSTANCE_VARIABLE_GET.bind_call(other, :@#{property.name.name})")
			buffer << " &&\n  " if i < n - 1
			i += 1
		end
		buffer << "  true" if n.zero?
		buffer << "\nend\n"
	end

	# Only a module is asked: asking a _Deferred would materialize it when the
	# property is declared, before the constant it names may exist.
	private def promises?(property, interface)
		Module === property.type && Literal.subtype?(property.type, interface)
	end

	# Refuse what Ruby can't compile as the initializer's parameters: a second
	# splat, double splat or block, and optional positional parameters that
	# aren't one contiguous run — or aren't last before a splat.
	def check_signature(sorted_properties = @sorted_properties)
		variadic = {}
		first_optional = nil
		required_after_optional = nil

		sorted_properties.each do |property|
			case property.kind
			in :* | :** | :&
				if (other = variadic[property.kind])
					raise Literal::ArgumentError.new(
						"#{property.name.inspect} can't be a #{property.kind.inspect} property, because #{other.name.inspect} already is.",
					)
				end

				variadic[property.kind] = property
			in :positional if property.optional?
				if required_after_optional
					raise Literal::ArgumentError.new(
						"The optional positional property #{property.name.inspect} can't follow the required #{required_after_optional.name.inspect}, because optional positional properties must be contiguous.",
					)
				end

				first_optional ||= property
			in :positional
				required_after_optional ||= property if first_optional
			in :keyword | :const
				nil
			end
		end

		if required_after_optional && variadic[:*]
			raise Literal::ArgumentError.new(
				"The required positional property #{required_after_optional.name.inspect} can't follow the optional #{first_optional.name.inspect}, because #{variadic[:*].name.inspect} is a splat.",
			)
		end
	end

	private def generate_initializer_params(buffer, locals)
		parameters = @sorted_properties.reject(&:const?)
		i, n = 0, parameters.size
		while i < n
			property = parameters[i]

			case property.kind
			when :*
				buffer << "*" << locals[property.name]
			when :**
				buffer << "**" << locals[property.name]
			when :&
				buffer << "&" << locals[property.name]
			when :positional
				if property.default? || property.undefinable? # optional
					buffer << locals[property.name] << " = ::Literal::Undefined"
				elsif property.nil_default?
					buffer << locals[property.name] << " = nil"
				else # required
					buffer << locals[property.name]
				end
			when :keyword
				if property.default? || property.undefinable? # optional
					buffer << property.name.name << ": ::Literal::Undefined"
				elsif property.nil_default?
					buffer << property.name.name << ": nil" # optional
				else # required
					buffer << property.name.name << ":"
				end
			else
				raise "You should never see this error."
			end

			i += 1
			buffer << ", " if i < n
		end

		buffer
	end

	private def generate_initializer_body(buffer, locals, property_local)
		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			property.generate_initializer_handle_property(buffer, local: locals[property.name], property_local:)
			i += 1
		end

		buffer
	end

	# Every name a local variable could take is also a property name, so the
	# initializer's own locals — a Ruby keyword's escape, and the property
	# being handled — take the first name with enough leading underscores that
	# no property has it.
	private def initializer_locals
		taken = Set.new(@properties_index.each_key.map(&:name))

		locals = @properties_index.to_h do |name, property|
			[name, property.ruby_keyword? ? unique_local("__#{name.name}__", taken) : name.name]
		end

		[locals, unique_local("__property__", taken)]
	end

	private def unique_local(name, taken)
		name = "_#{name}" while taken.include?(name)
		taken << name
		name
	end
end
