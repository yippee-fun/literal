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
end
