# frozen_string_literal: true

class Literal::Data < Literal::DataStructure
	class << self
		def [](...) = new(...)

		# Frozen before its checks see it, so a check judges a finished value
		# exactly as it does on the initializer path.
		private def __literal_from_props__(props, seal: true)
			Literal::FREEZE.bind_call(super)
		end

		def define(**properties, &body)
			Class.new(self) do
				props do
					properties.each { |name, type| prop(name, type) }
				end

				if block_given?
					class_eval(&body)
				end
			end
		end

		def prop(name, type, kind = :keyword, reader: :public, predicate: false, default: nil, description: nil, &coercion)
			super(name, type, kind, reader:, writer: false, predicate:, default:, description:, &coercion)
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

	# Copies stay frozen, like Ruby's Data.
	private def initialize_copy(source)
		super
		Literal::FREEZE.bind_call(self)
	end
end
