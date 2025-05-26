# frozen_string_literal: true

class Literal::Set
	class Generic
		def initialize(type)
			@type = type
		end

		def new(*value)
			Literal::Set.new(value.to_set, type: @type)
		end

		alias_method :[], :new

		def ===(value)
			Literal::Set === value && @type == value.__type__
		end

		def inspect
			"Literal::Set(#{@type.inspect})"
		end
	end

	include Enumerable

	def initialize(value, type:)
		collection_type = Literal::Types::SetType.new(type)

		Literal.check(value, collection_type) do |c|
			c.fill_receiver(receiver: self, method: "#initialize")
		end

		@__type__ = type
		@__value__ = value
		@__collection_type__ = collection_type
	end

	attr_reader :__type__, :__value__

	def freeze
		@__value__.freeze
		super
	end

	def each(...)
		@__value__.each(...)
	end
end
