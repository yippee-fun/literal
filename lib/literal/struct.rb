# frozen_string_literal: true

class Literal::Struct < Literal::DataStructure
	class << self
		def prop(name, type, kind = :keyword, reader: :public, writer: :public, predicate: false, default: nil, description: nil)
			super
		end

		def const(name, value, reader: :public, description: nil, &)
			super
		end
	end

	def []=(key, value)
		case key
		when Symbol
		when String
			key = key.intern
		else
			::Kernel.raise TypeError.new("expected a string or symbol, got #{key.class}")
		end

		shape = Literal::CLASS.bind_call(self)
		prop = shape.literal_properties[key] || ::Kernel.raise(NameError.new("unknown attribute: #{key.inspect} for #{shape}"))
		Literal::PUBLIC_SEND.bind_call(self, :"#{prop.name.name}=", value)
	end
end
