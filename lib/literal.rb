# frozen_string_literal: true

require "zeitwerk"
require_relative "literal/version"

module Literal
	Loader = Zeitwerk::Loader.for_gem.tap do |loader|
		loader.ignore("#{__dir__}/literal/rails")
		loader.ignore("#{__dir__}/literal/railtie.rb")
		loader.ignore("#{__dir__}/ruby_lsp")

		loader.inflector.inflect(
			"json_data_type" => "JSONDataType"
		)

		loader.collapse("#{__dir__}/literal/flags")
		loader.collapse("#{__dir__}/literal/errors")

		loader.setup
	end

	CLASS_METHOD = Kernel.instance_method(:class)
	CLASS_VARIABLE_GET_METHOD = Module.instance_method(:class_variable_get)
	INSTANCE_VARIABLE_GET_METHOD = Kernel.instance_method(:instance_variable_get)

	module BindingAssert
		def assert(...)
			Literal.assert(self, ...)
		end
	end

	::Binding.include(Literal::BindingAssert)


	def self.assert(bind, **kwargs)
		kwargs.each do |name, type|
			string_name = (Symbol === name) ? name.name : name
			first_byte = string_name.getbyte(0)

			if first_byte == 64 # @foo
				if string_name.getbyte(1) == 64 # @@foo
					value = CLASS_VARIABLE_GET_METHOD.bind_call(
						CLASS_METHOD.bind_call(bind.receiver), name
					)
				else # @foo
					value = INSTANCE_VARIABLE_GET_METHOD.bind_call(bind.receiver, name)
				end
			elsif first_byte == 36 # $foo
				raise if string_name.match?(/[\s\.]/)
				value = eval(string_name)
			else # foo
				value = bind.local_variable_get(name)
			end

			unless type === value
				raise ::TypeError.new(<<~MESSAGE)
					Assertion failed!

					  #{name}
					    Expected: #{type.inspect}
					    Actual (#{value.class}): #{value.inspect}
				MESSAGE
			end
		end
	end


	def self.Value(*args, **kwargs, &block)
		value_class = Class.new(Literal::Value)

		type = Literal::Types._Constraint(*args, **kwargs)
		value_class.define_method(:__type__) { type }

		if subtype?(type, Integer)
			value_class.alias_method :to_i, :value
		elsif subtype?(type, String)
			value_class.alias_method :to_s, :value
			value_class.alias_method :to_str, :value
		elsif subtype?(type, Array)
			value_class.alias_method :to_a, :value
			value_class.alias_method :to_ary, :value
		elsif subtype?(type, Hash)
			value_class.alias_method :to_h, :value
		elsif subtype?(type, Float)
			value_class.alias_method :to_f, :value
		elsif subtype?(type, Set)
			value_class.alias_method :to_set, :value
		end

		value_class.class_eval(&block) if block
		value_class.freeze
	end

	def self.Delegator(*args, **kwargs, &block)
		delegator_class = Class.new(Literal::Delegator)

		type = Literal::Types._Constraint(*args, **kwargs)
		delegator_class.define_method(:__type__) { type }

		delegator_class.class_eval(&block) if block
		delegator_class.freeze
	end

	def self.Enum(type)
		Class.new(Literal::Enum) do
			prop :value, type, :positional, reader: :public
		end
	end

	def self.Array(type)
		Literal::Array::Generic.new(type)
	end

	def self.Set(type)
		Literal::Set::Generic.new(type)
	end

	def self.Hash(key_type, value_type)
		Literal::Hash::Generic.new(key_type, value_type)
	end

	def self.Tuple(*types)
		Literal::Tuple::Generic.new(*types)
	end

	def self.Brand(...)
		Literal::Brand.new(...)
	end

	def self.check(value, type)
		if type === value
			true
		else
			context = Literal::TypeError::Context.new(expected: type, actual: value)
			type.record_literal_type_errors(context) if type.respond_to?(:record_literal_type_errors)
			yield context if block_given?
			raise Literal::TypeError.new(context:)
		end
	end

	def self.subtype?(type, supertype)
		subtype = type

		subtype = subtype.block.call if Types::DeferredType === subtype

		return true if supertype == subtype

		case supertype
		when Literal::Type
			supertype >= subtype
		when Module
			case subtype
			when Module
				supertype >= subtype
			when Numeric
				Numeric >= supertype
			when String
				String >= supertype
			when Symbol
				Symbol >= supertype
			when ::Array
				::Array >= supertype
			when ::Hash
				::Hash >= supertype
			else
				false
			end
		when Range
			supertype.cover?(subtype)
		else
			false
		end
	end
end

require_relative "literal/railtie" if defined?(Rails)
