# frozen_string_literal: true

class Literal::Data < Literal::DataStructure
	class << self
		def [](...) = new(...)

		# Frozen before its checks see it, so a check judges a finished value
		# exactly as it does on the initializer path.
		private def __literal_from_props__(props, seal: true)
			super.freeze
		end

		def define(**properties)
			Class.new(self) do
				properties.each { |name, type| prop(name, type) }
			end
		end

		def prop(name, type, kind = :keyword, reader: :public, predicate: false, default: nil, description: nil, &coercion)
			super(name, type, kind, reader:, writer: false, predicate:, default:, description:, &coercion)
		end

		def prop?(name, type, kind = :keyword, reader: :public, predicate: false, description: nil, &coercion)
			prop(
				name,
				Literal::Types._Union(type, Literal::Undefined),
				kind,
				reader:,
				predicate:,
				description:,
				&coercion
			)
		end

		def literal_properties
			return @literal_properties if defined?(@literal_properties)

			if superclass < Literal::Data
				@literal_properties = superclass.literal_properties.dup
			else
				@literal_properties = Literal::Properties::DataSchema.new
			end
		end
	end

	def with(**changes)
		return self if changes.empty?

		properties = self.class.literal_properties
		props = to_h

		changes.each do |name, value|
			property = properties[name] || raise(NameError.new("unknown attribute: #{name.inspect} for #{self.class}"))
			value = property.coerce(value, context: self) if property.coercion
			value = property.seal.call(value) if property.seal
			props[name] = value
		end

		# The initializer's lifecycle, minus the coercion carried-over values
		# already went through: assign, after_initialize, freeze, then checks.
		copy = self.class.allocate
		copy.__send__(:__literal_assign_props__, props, "#with", seal: false)
		copy.__send__(:after_initialize) if copy.respond_to?(:after_initialize, true)
		copy.freeze
		copy.__send__(:__literal_run_checks__)
		copy
	end
end
