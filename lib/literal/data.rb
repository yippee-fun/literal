# frozen_string_literal: true

class Literal::Data < Literal::DataStructure
	class << self
		def [](...) = new(...)

		def prop(name, type, kind = :keyword, reader: :public, predicate: false, default: nil)
			super(name, type, kind, reader:, writer: false, predicate:, default:)
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
