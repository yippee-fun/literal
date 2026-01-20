# frozen_string_literal: true

# @api private
class Literal::Properties::Schema
	include Enumerable

	def initialize(properties_index: {}, sorted_properties: [])
		@properties_index = properties_index
		@sorted_properties = sorted_properties
		@mutex = Mutex.new
	end

	attr_reader :properties_index

	def [](key)
		@properties_index[key]
	end

	def <<(value)
		@mutex.synchronize do
			@properties_index[value.name] = value
			# ruby's sort is unstable, this trick makes it stable
			n = 0
			@sorted_properties = @properties_index.values.sort_by! { |it| n += 1; [it, n] }
		end

		self
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

	def generate_initializer(buffer = +"")
		buffer << "alias initialize initialize\n" \
			"def initialize("
		generate_initializer_params(buffer)
		buffer << ")\n"
		generate_initializer_body(buffer)
		buffer << "" \
			"rescue Literal::TypeError => error\n" \
			"  error.set_backtrace(caller(2))\n" \
			"  raise\n" \
			"else\n"
		generate_after_initializer(buffer)
		buffer << "end\n"
	end

	def generate_after_initializer(buffer = +"")
		buffer << "  after_initialize if respond_to?(:after_initialize, true)\n"
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
		buffer << "def hash\n  [self.class,\n"

		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			buffer << "  @" << property.name.name << ",\n"
			i += 1
		end

		buffer << "  ].hash\n" << "end\n"
	end

	def generate_eq(buffer = +"")
		buffer << "def ==(other)\n"
		buffer << "  return false unless self.class === other && other.class.literal_properties.size == self.class.literal_properties.size\n"

		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]
			buffer << "  @#{property.name.name} == other.instance_variable_get(:@#{property.name.name})"
			buffer << " &&\n  " if i < n - 1
			i += 1
		end
		buffer << "  true" if n.zero?
		buffer << "\nend\n"
		buffer << "alias eql? ==\n"
	end

	private def generate_initializer_params(buffer = +"")
		sorted_properties = @sorted_properties
		i, n = 0, sorted_properties.size
		while i < n
			property = sorted_properties[i]

			case property.kind
			when :*
				buffer << "*" << property.escaped_name
			when :**
				buffer << "**" << property.escaped_name
			when :&
				buffer << "&" << property.escaped_name
			when :positional
				if property.default?
					buffer << property.escaped_name << " = Literal::Undefined"
				elsif property.type === nil # optional
					buffer << property.escaped_name << " = nil"
				else # required
					buffer << property.escaped_name
				end
			when :keyword
				if property.default?
					buffer << property.name.name << ": Literal::Undefined"
				elsif property.type === nil
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

	private def generate_initializer_body(buffer = +"")
		buffer << "  __properties__ = self.class.literal_properties.properties_index\n"
		generate_initializer_handle_properties(@sorted_properties, buffer)
	end

	private def generate_initializer_handle_properties(properties, buffer = +"")
		i, n = 0, properties.size
		while i < n
			properties[i].generate_initializer_handle_property(buffer)
			i += 1
		end

		buffer
	end
end
