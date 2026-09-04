# frozen_string_literal: true

class Literal::Property
	ORDER = { :positional => 0, :* => 1, :keyword => 2, :** => 3, :& => 4, :const => 5 }.freeze
	RUBY_KEYWORDS = %i[alias and begin break case class def do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield].to_h { |k| [k, "__#{k}__"] }.freeze

	VISIBILITY_OPTIONS = Set[false, :private, :protected, :public].freeze
	VISIBILITY_ORDER = { false => 0, :private => 1, :protected => 2, :public => 3 }.freeze
	KIND_OPTIONS = Set[:positional, :*, :keyword, :**, :&, :const].freeze

	include Comparable

	def initialize(name:, type:, kind:, reader:, writer:, predicate:, default:, description:, coercion:, seal: nil)
		@name = name
		@type = type
		@kind = kind
		@reader = reader
		@writer = writer
		@predicate = predicate
		@default = default
		@description = description
		@coercion = coercion
		@seal = seal
	end

	attr_reader :name, :type, :kind, :reader, :writer, :predicate, :default, :description, :coercion, :seal

	def optional?
		default? || @type === nil || undefinable?
	end

	# Whether the type is a union containing the exact `Literal::Undefined`
	# object — the shape `_Optional` builds — i.e. the value may be omitted.
	# Containment, not `===`: the sentinel is a truthy object, so types like
	# `_Truthy` merely match it without meaning "omittable". Blocks are
	# excluded because Ruby resolves an omitted block to `nil`, so a block
	# parameter can never receive `Literal::Undefined`.
	def undefinable?
		:& != @kind && Literal::Types::UnionType === @type && @type.optional?
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

	def const?
		@kind == :const
	end

	# The instance variable this property is stored in. Generated code writes
	# `@name` literally; this is for the runtime paths that cannot.
	def __ivar__
		@__ivar__ ||= :"@#{@name.name}"
	end

	def default?
		return true if splat? || double_splat?
		nil != @default
	end

	def description?
		!!@description
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

	def generate_writer_method(buffer = +"", checked: false)
		buffer <<
			(@writer ? @writer.name : "public") <<
			" def " <<
			@name.name <<
			"=(value)\n" <<
			"  __property__ = self.class.literal_properties[:" <<
			@name.name <<
			"]\n"

		if @coercion
			buffer << "  value = __property__.coerce(value, context: self)\n"
		end

		if @seal
			buffer << "  value = __property__.seal.call(value)\n"
		end

		buffer << "  __property__.check_writer(self, value)\n"

		if checked
			# Judged before it is written, against the prospective value standing
			# in this property's place — so a check that fails, or raises out of a
			# bug, leaves the object untouched. A write must not half-happen.
			buffer << "  __literal_run_checks__(:" << @name.name << ", value)\n"
		end

		buffer << "  @" << @name.name << " = value\n"

		buffer <<
			"rescue Literal::TypeError => error\n  error.set_backtrace(caller(1))\n  raise\n" <<
			"end\n"
	end

	def generate_predicate_method(buffer = +"")
		buffer <<
			(@predicate ? @predicate.name : "public") <<
			" def " <<
			@name.name <<
			"?\n"

		# The Undefined sentinel is truthy, so an unset optional property has
		# to answer false explicitly. Properties that can never hold it skip
		# the extra comparison.
		if undefinable?
			buffer <<
				"  Literal::Undefined != @" <<
				@name.name <<
				" && !!@" <<
				@name.name <<
				"\n"
		else
			buffer <<
				"  !!@" <<
				@name.name <<
				"\n"
		end

		buffer << "end\n"
	end

	def generate_initializer_handle_property(buffer = +"")
		buffer << "  # " << @name.name << "\n"

		if const?
			buffer << "  @" << @name.name << " = __properties__[:" << @name.name << "].default\n"
			return buffer
		end

		buffer << "  __property__ = __properties__[:" << @name.name << "]\n"

		if @kind == :keyword && ruby_keyword?
			generate_initializer_escape_keyword(buffer)
		end

		if default?
			generate_initializer_assign_default(buffer)
		end

		if @coercion
			generate_initializer_coerce_property(buffer)
		end

		if @seal
			generate_initializer_seal_property(buffer)
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

	private def generate_initializer_seal_property(buffer = +"")
		buffer <<
			escaped_name <<
			"= __property__.seal.call(" <<
			escaped_name <<
			")\n"
	end

	private def generate_initializer_assign_default(buffer = +"")
		buffer <<
			"  if " <<
			((@kind == :&) ? "nil" : "Literal::Undefined") <<
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
