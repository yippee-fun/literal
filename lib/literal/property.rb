# frozen_string_literal: true

class Literal::Property
	ORDER = { :positional => 0, :* => 1, :keyword => 2, :** => 3, :& => 4 }.freeze
	RUBY_KEYWORDS = %i[alias and begin break case class def do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield].to_h { |k| [k, "__#{k}__"] }.freeze

	VISIBILITY_OPTIONS = Set[false, :private, :protected, :public].freeze
	KIND_OPTIONS = Set[:positional, :*, :keyword, :**, :&].freeze

	include Comparable

	def initialize(name:, type:, kind:, reader:, writer:, predicate:, default:, coercion:)
		@name = name
		@type = type
		@kind = kind
		@reader = reader
		@writer = writer
		@predicate = predicate
		@default = default
		@coercion = coercion
	end

	attr_reader :name, :type, :kind, :reader, :writer, :predicate, :default, :coercion

	def optional?
		default? || @type === nil
	end

	def required?
		!optional?
	end

	def keyword?
		@kind == :keyword
	end

	def positional?
		@kind == :positional
	end

	def splat?
		@kind == :*
	end

	def double_splat?
		@kind == :**
	end

	def block?
		@kind == :&
	end

	def default?
		nil != @default
	end

	def param
		case @kind
		when :*
			"*#{escaped_name}"
		when :**
			"**#{escaped_name}"
		when :&
			"&#{escaped_name}"
		when :positional
			escaped_name
		when :keyword
			"#{@name.name}:"
		else
			raise "You should never see this error."
		end
	end

	def <=>(other)
		ORDER[@kind] <=> ORDER[other.kind]
	end

	def coerce(value, context:)
		context.instance_exec(value, &@coercion)
	end

	def ruby_keyword?
		!!RUBY_KEYWORDS[@name]
	end

	def escaped_name
		RUBY_KEYWORDS[@name] || @name.name
	end

	def default_value(receiver)
		case @default
			when Proc then receiver.instance_exec(&@default)
			else @default
		end
	end

	def check(value, &)
		raise ArgumentError.new("Cannot check type without a block") unless block_given?

		Literal.check(value, @type, &)
	end

	def check_writer(receiver, value)
		Literal.check(value, @type) { |c| c.fill_receiver(receiver:, method: "##{@name.name}=(value)") }
	end

	def check_initializer(receiver, value)
		Literal.check(value, @type) { |c| c.fill_receiver(receiver:, method: "#initialize", label: param) }
	end

	def generate_reader_method(buffer = +"")
		buffer <<
			(@reader ? @reader.name : "public") <<
			"\ndef " <<
			@name.name <<
			"\n  value = @" <<
			@name.name <<
			"\n  value\nend\n"
	end

	def generate_writer_method(buffer = +"")
		buffer <<
			(@writer ? @writer.name : "public") <<
			" def " <<
			@name.name <<
			"=(value)\n" <<
			"  self.class.literal_properties[:" <<
			@name.name <<
			"].check_writer(self, value)\n" <<
			"  @" << @name.name << " = value\n" <<
			"rescue Literal::TypeError => error\n  error.set_backtrace(caller(1))\n  raise\n" <<
			"end\n"
	end

	def generate_predicate_method(buffer = +"")
		buffer <<
			(@predicate ? @predicate.name : "public") <<
			" def " <<
			@name.name <<
			"?\n" <<
			"  !!@" <<
			@name.name <<
			"\n" <<
			"end\n"
	end

	def generate_initializer_handle_property(buffer = +"")
		buffer << "  # " << @name.name << "\n" <<
			"  __property__ = __properties__[:" << @name.name << "]\n"

		if @kind == :keyword && ruby_keyword?
			generate_initializer_escape_keyword(buffer)
		end

		if default?
			generate_initializer_assign_default(buffer)
		end

		if @coercion
			generate_initializer_coerce_property(buffer)
		end

		generate_initializer_check_type(buffer)
		generate_initializer_assign_value(buffer)
	end

	private def generate_initializer_escape_keyword(buffer = +"")
		buffer <<
			escaped_name <<
			" = binding.local_variable_get(:" <<
			@name.name <<
			")\n"
	end

	private def generate_initializer_coerce_property(buffer = +"")
		buffer <<
			escaped_name <<
			"= __property__.coerce(" <<
			escaped_name <<
			", context: self)\n"
	end

	private def generate_initializer_assign_default(buffer = +"")
		buffer <<
			"  if " <<
			((@kind == :&) ? "nil" : "Literal::Null") <<
			" == " <<
			escaped_name <<
			"\n    " <<
			escaped_name <<
			" = __property__.default_value(self)\n  end\n"
	end

	private def generate_initializer_check_type(buffer = +"")
		buffer <<
			"  __property__.check_initializer(self, " << escaped_name << ")\n"
	end

	private def generate_initializer_assign_value(buffer = +"")
		buffer <<
			"  @" <<
			@name.name <<
			" = " <<
			escaped_name <<
			"\n"
	end
end
