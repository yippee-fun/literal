# frozen_string_literal: true

class Literal::Hash
	class Generic
		def initialize(key_type, value_type)
			@key_type = key_type
			@value_type = value_type
		end

		def new(**value)
			Literal::Hash.new(value, key_type: @key_type, value_type: @value_type)
		end

		def ===(value)
			Literal::Hash === value && @type == value.__type__
		end

		def inspect
			"Literal::Hash(#{@type.inspect})"
		end
	end

	include Enumerable

	def initialize(value, key_type:, value_type:)
		collection_type = Literal::Types::HashType.new(key_type, value_type)

		Literal.check(value, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__key_type__ = key_type
		@__value_type__ = value_type
		@__value__ = value
		@__collection_type__ = collection_type
	end

	attr_reader :__key_type__, :__value_type__, :__value__

	def freeze
		@__value__.freeze
		super
	end

	def each(...)
		@__value__.each(...)
	end
end
