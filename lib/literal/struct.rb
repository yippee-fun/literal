# frozen_string_literal: true

class Literal::Struct < Literal::DataStructure
	class << self
		def prop(name, type, kind = :keyword, reader: :public, writer: :public, default: nil, description: nil)
			super
		end
	end

	def [](key)
		case key
		when Symbol
		when String
			key = key.intern
		else
			raise TypeError.new("expected a string or symbol, got #{key.inspect.class}")
		end

		prop = self.class.literal_properties[key] || raise(NameError.new("unknown attribute: #{key.inspect} for #{self.class}"))
		__send__(prop.name)
	end

	def []=(key, value)
		case key
		when Symbol
		when String
			key = key.intern
		else
			raise TypeError.new("expected a string or symbol, got #{key.inspect.class}")
		end

		prop = self.class.literal_properties[key] || raise(NameError.new("unknown attribute: #{key.inspect} for #{self.class}"))
		__send__(:"#{prop.name}=", value)
	end
end
