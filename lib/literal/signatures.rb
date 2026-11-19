# frozen_string_literal: true

# Runtime-checked method signatures, written on the line above the method in
# the shape of an RBS inline annotation:
#
#   class Greeter
#     extend Literal::Signatures
#
#     #: (String, ?greeting: String?) -> String
#     sig(String, greeting: _Nilable(String)) >> String
#     def greet(name, greeting: nil) = "#{greeting || "Hello"}, #{name}"
#   end
#
# Positional types line up with the method's positional parameters, and
# keyword types with its keywords by name; the type after `>>` is the return
# type. The method stays a plain `def`, so editors, YARD, stack traces and
# method cops all see it as written. Each argument the caller passes is checked
# before the method runs and the return value after, raising
# Literal::TypeError. A default is the author's own and is not checked.
#
# A signature binds to the next method defined, instance or singleton. One that
# does not match that method's parameters fails when the class loads, as does
# a `sig` with no `>>`, two in a row, or one the class body ends on.
#
# The checking method is compiled to the method's own parameter list, so one
# that takes only required parameters allocates nothing to be checked; any
# optional positional or keyword parameters may cost the Array or Hash that
# carries them through, depending on the Ruby.
module Literal::Signatures
	include Literal::Types

	# @api private
	class Signature
		def initialize(positional, keywords, site)
			@positional = positional
			@keywords = keywords
			@site = site
			@returns = Literal::Undefined
		end

		attr_reader :positional, :keywords, :site, :returns

		def >>(other)
			@returns = other
			self
		end

		def returns? = !(Literal::Undefined === @returns)
	end

	POSITIONAL = [:req, :opt].freeze
	KEYWORD = [:keyreq, :key].freeze

	# The method names `def` can spell, so the checker can be compiled under its
	# own name; it is compiled under a stand-in for any other.
	IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*[?!=]?\z/
	OPERATORS = [:[], :[]=, :+, :-, :*, :/, :%, :**, :==, :!=, :===, :=~, :!~, :<, :>, :<=, :>=, :<=>, :<<, :>>, :&, :|, :^, :~, :!, :+@, :-@, :`].freeze

	def sig(*positional, **keywords)
		if (pending = @__literal_signature__)
			@__literal_signature__ = nil
			@__literal_signature_watch__&.disable
			raise Literal::ArgumentError, "#{self}: the sig at #{pending.site} has no method after it"
		end

		@__literal_signature__ = Signature.new(positional.freeze, keywords.freeze, caller_locations(1, 1).first)
		__literal_await_method__
		@__literal_signature__
	end

	private def method_added(name)
		super
		__literal_bind_signature__(self, name)
	end

	private def singleton_method_added(name)
		super
		__literal_bind_signature__(singleton_class, name)
	end

	private def __literal_bind_signature__(owner, name)
		signature = @__literal_signature__ or return
		@__literal_signature__ = nil
		@__literal_signature_watch__&.disable

		singleton = !owner.equal?(self)
		original = owner.instance_method(name)
		prepended = !Literal::EQUAL.bind_call(original.owner, owner)
		original = original.super_method until Literal::EQUAL.bind_call(original.owner, owner)
		parameters = original.parameters
		__literal_refuse_mismatch__(signature, parameters, "#{self}#{singleton ? '.' : '#'}#{name}")

		visibility = __literal_visibility__(owner, name)
		unsigned = :"__literal_unsigned_#{Literal::OBJECT_ID.bind_call(owner)}_#{name.object_id}__"

		# alias_method resolves through prepended modules, so past one, copy the
		# class's own definition. JRuby names a copy's frames and super calls
		# after the copy, so alias where we can.
		if prepended
			owner.define_method(unsigned, original)
		else
			owner.alias_method(unsigned, name)
		end

		owner.__send__(:private, unsigned)

		checker = Module.new
		keywords = signature.keywords.values_at(*__literal_keywords__(parameters))
		checker.const_set(:TYPES, [*signature.positional, *keywords, signature.returns].freeze)
		compiled = (IDENTIFIER.match?(name) || OPERATORS.include?(name)) ? name : :__literal_checker__
		code = __literal_checker_code__(compiled, unsigned, parameters, singleton ? "#{self}.#{name}" : "##{name}", singleton)
		# An explicit path, so every engine attributes these frames to Literal.
		checker.module_eval(code, __FILE__, __LINE__)

		owner.define_method(name, checker.instance_method(compiled))
		owner.__send__(visibility, name)
	end

	# The checking method, taking the parameters the method takes. Positional
	# arguments get names of their own, since a positional's name is not part
	# of the call; a keyword named after a reserved word is read off the binding.
	private def __literal_checker_code__(name, unsigned, parameters, method, singleton)
		receiver = singleton ? "nil" : "self"
		positional = parameters.filter_map { |kind, param| param if POSITIONAL.include?(kind) }
		required = parameters.count { |kind, _| :req == kind }
		keyword_order = __literal_keywords__(parameters)
		keywords = parameters.filter_map { |kind, param| param if :keyreq == kind }
		options = parameters.filter_map { |kind, param| param if :key == kind }

		read = -> (key) { Literal::Property::RUBY_KEYWORDS.key?(key) ? "::Kernel.binding.local_variable_get(:#{key})" : key.to_s }
		check = lambda do |value, index, label|
			"::Literal.check(#{value}, TYPES[#{index}]) { |c| c.fill_receiver(receiver: #{receiver}, method: #{method.inspect}, label: #{label.inspect}) }"
		end

		taken = parameters.map { |_, param| param }
		fresh = lambda do |local|
			local = :"_#{local}" while taken.include?(local)
			taken << local
			local
		end

		required_locals = Array.new(required) { |index| fresh.(:"__literal_arg_#{index}__") }
		optional = fresh.(:__literal_optional__)
		options_local = fresh.(:__literal_options__)
		returned = fresh.(:__literal_returned__)

		arguments = required_locals.map(&:name)
		arguments << "*#{optional}" if positional.size > required
		arguments.concat(keywords.map { |key| "#{key}:" })
		arguments << "**#{options_local}" if options.any?
		arguments << "**nil" if parameters.any? { |kind, _| :nokey == kind }
		arguments << "&"

		checks = required_locals.each_with_index.map { |local, index| check.(local, index, positional[index].to_s) }
		(required...(positional.size)).each_with_index do |index, offset|
			checks << "#{check.("#{optional}[#{offset}]", index, positional[index].to_s)} if #{optional}.size > #{offset}"
		end
		keywords.each { |key| checks << check.(read.(key), positional.size + keyword_order.index(key), "#{key}:") }
		options.each do |key|
			checks << "#{check.("#{options_local}[:#{key}]", positional.size + keyword_order.index(key), "#{key}:")} if #{options_local}.key?(:#{key})"
		end

		call = required_locals.map(&:name)
		call << "*#{optional}" if positional.size > required
		call.concat(keywords.map { |key| "#{key}: #{read.(key)}" })
		call << "**#{options_local}" if options.any?
		call << "&"

		<<~RUBY
			# frozen_string_literal: true
			def #{name}(#{arguments.join(', ')})
				#{checks.join("\n")}
				#{returned} = #{unsigned}(#{call.join(', ')})
				#{check.(returned, positional.size + keyword_order.size, 'return')}
				#{returned}
			end
		RUBY
	end

	private def __literal_keywords__(parameters) = parameters.filter_map { |kind, param| param if KEYWORD.include?(kind) }

	# Every mismatch here is a typo the class should not load with.
	private def __literal_refuse_mismatch__(signature, parameters, label)
		site = "#{label} (sig at #{signature.site})"

		unless signature.returns?
			raise Literal::ArgumentError, "#{site} has no return type; write sig(...) >> Type, or >> _Void"
		end

		if (unsupported = parameters.find { |kind, param| :rest == kind || :keyrest == kind || (:req == kind && !param) })
			raise Literal::ArgumentError, "#{site} takes #{unsupported[1] || 'a destructured argument'} as a splat or pattern, which a sig cannot type yet"
		end

		positional = parameters.count { |kind, _| POSITIONAL.include?(kind) }
		keywords = __literal_keywords__(parameters)

		if parameters.drop_while { |kind, _| :opt != kind }.any? { |kind, _| :req == kind }
			raise Literal::ArgumentError, "#{site} takes a required argument after an optional one, which a sig cannot type yet"
		end

		unless positional == signature.positional.size
			raise Literal::ArgumentError,
				"#{site} takes #{positional} positional #{(positional == 1) ? 'argument' : 'arguments'}, its sig types #{signature.positional.size}"
		end

		unless keywords.sort == signature.keywords.keys.sort
			raise Literal::ArgumentError, "#{site} takes keywords #{keywords.inspect}, its sig types #{signature.keywords.keys.inspect}"
		end
	end

	private def __literal_visibility__(owner, name)
		if owner.private_method_defined?(name, false) then :private
		elsif owner.protected_method_defined?(name, false) then :protected
		else :public
		end
	end

	# Watches this module's own `end`, and only until the next method is
	# defined. A `Class.new` block has no `end` event, and TruffleRuby has no
	# TracePoint, so there a sig with nothing after it is caught by the next sig.
	private def __literal_await_method__
		return if RUBY_ENGINE == "truffleruby"

		owner = self
		signature = @__literal_signature__
		@__literal_signature_watch__ = TracePoint.new(:end) do |tp|
			next unless Literal::EQUAL.bind_call(tp.self, owner)

			tp.disable
			Literal::INSTANCE_VARIABLE_SET.bind_call(owner, :@__literal_signature__, nil)
			raise Literal::ArgumentError, "#{owner}: the sig at #{signature.site} has no method after it"
		end
		@__literal_signature_watch__.enable
	end
end
