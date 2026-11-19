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
# The checking method is compiled to the method's own parameter list, so Ruby
# refuses a wrong number of arguments or an unknown keyword before anything is
# checked, and checking allocates nothing, save a Hash to pass on the given
# keywords when an optional one is omitted or the method is under a prepended
# override.
module Literal::Signatures
	include Literal::Types

	# @api private
	class Signature
		NO_RETURN_TYPE = Object.new.freeze
		private_constant :NO_RETURN_TYPE

		def initialize(positional, keywords, site)
			@positional = positional
			@keywords = keywords
			@site = site
			@returns = NO_RETURN_TYPE
		end

		attr_reader :positional, :keywords, :site, :returns

		def >>(other)
			@returns = other
			self
		end

		def returns? = !NO_RETURN_TYPE.equal?(@returns)
	end

	POSITIONAL = [:req, :opt].freeze
	KEYWORD = [:keyreq, :key].freeze

	# The method names `def` can spell, so the checker can be compiled under its
	# own name; it is compiled under a stand-in for any other.
	IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*[?!=]?\z/
	OPERATORS = [:[], :[]=, :+, :-, :*, :/, :%, :**, :==, :!=, :===, :=~, :!~, :<, :>, :<=, :>=, :<=>, :<<, :>>, :&, :|, :^, :~, :!, :+@, :-@, :`].freeze

	OMITTED = Object.new.freeze
	private_constant :OMITTED

	def sig(*positional, **keywords)
		if (pending = @__literal_signature__)
			@__literal_signature__ = nil
			__literal_stop_watching__
			raise Literal::ArgumentError, "#{self}: the sig at #{pending.site} has no method after it"
		end

		@__literal_signature__ = Signature.new(positional.freeze, keywords.freeze, caller_locations(1, 1).first)
		singleton_class.prepend(MethodHooks) unless singleton_class.include?(MethodHooks)
		__literal_await_method__
		@__literal_signature__
	end

	# Prepended, so a class's own hooks cannot hide a method from its sig by not
	# calling super. They see the method once it is signed, so one defining a
	# method of its own cannot take the sig, and do not see the methods signing
	# defines.
	module MethodHooks
		private def method_added(name)
			return if @__literal_signing__

			__literal_bind_signature__(self, name)
			super
		end

		private def singleton_method_added(name)
			return if @__literal_signing__

			__literal_bind_signature__(singleton_class, name)
			super
		end
	end
	private_constant :MethodHooks

	private def __literal_bind_signature__(owner, name)
		signature = @__literal_signature__ or return
		@__literal_signature__ = nil
		__literal_stop_watching__
		@__literal_signing__ = true

		singleton = !owner.equal?(self)
		original = owner.instance_method(name)
		prepended = !Literal::EQUAL.bind_call(original.owner, owner)
		original = original.super_method until Literal::EQUAL.bind_call(original.owner, owner)
		parameters = original.parameters
		__literal_refuse_mismatch__(signature, parameters, "#{self}#{singleton ? '.' : '#'}#{name}")

		visibility = __literal_visibility__(owner, name)
		checker = Module.new

		# alias_method resolves through prepended modules, so past one, call the
		# class's own definition through bind_call. A copy would do on MRI, but
		# JRuby names a copy's super calls after the copy.
		if prepended
			checker.const_set(:ORIGINAL, original)
			callee = "ORIGINAL.bind_call(self, "
		else
			unsigned = :"__literal_unsigned_#{Literal::OBJECT_ID.bind_call(owner)}_#{name.object_id}__"
			owner.alias_method(unsigned, name)
			owner.__send__(:private, unsigned)
			callee = "#{unsigned}("
		end

		keywords = signature.keywords.values_at(*__literal_keywords__(parameters))
		checker.const_set(:TYPES, [*signature.positional, *keywords, signature.returns].freeze)
		checker.const_set(:OMITTED, OMITTED)
		compiled = (IDENTIFIER.match?(name) || OPERATORS.include?(name)) ? name : :__literal_checker__
		code = __literal_checker_code__(compiled, callee, parameters, singleton ? "#{self}.#{name}" : "##{name}", singleton)
		# An explicit path, so every engine attributes these frames to Literal.
		checker.module_eval(code, __FILE__, __LINE__)

		owner.define_method(name, checker.instance_method(compiled))
		owner.__send__(visibility, name)
	ensure
		@__literal_signing__ = false
	end

	# The checking method, taking the parameters the method takes under the same
	# names, so Method#parameters reads the same, save a block parameter. An
	# optional parameter defaults to OMITTED, so an omitted argument is left out
	# of the call and the method's own default applies. A keyword keeps its name,
	# since it is part of the call, and any other parameter repeating an
	# underscore name gets one of its own; a keyword named after a reserved word
	# is read off the binding.
	private def __literal_checker_code__(name, callee, parameters, method, singleton)
		receiver = singleton ? "nil" : "self"
		check = lambda do |value, index, label|
			"::Literal.check(#{value}, TYPES[#{index}]) { |c| c.fill_receiver(receiver: #{receiver}, method: #{method.inspect}, label: #{label.inspect}) }"
		end

		taken = parameters.map { |_, param| param }
		fresh = lambda do |local|
			local = :"_#{local}" while taken.include?(local)
			taken << local
			local
		end

		positional = parameters.select { |kind, _| POSITIONAL.include?(kind) }
		keywords = parameters.select { |kind, _| KEYWORD.include?(kind) }
		claimed = keywords.map { |_, key| key }
		locals = positional.map do |_, param|
			local = claimed.include?(param) ? fresh.(param) : param
			claimed << local
			local
		end
		values = keywords.to_h { |_, key| [key, Literal::Property::RUBY_KEYWORDS.key?(key) ? fresh.(:"__literal_#{key}__") : key] }
		options = fresh.(:__literal_options__)
		returned = fresh.(:__literal_returned__)
		block = parameters.find { |kind, param| :block == kind && :& != param && !claimed.include?(param) }&.last || fresh.(:block)

		arguments = positional.zip(locals).map { |(kind, _), local| (:opt == kind) ? "#{local} = OMITTED" : local.name }
		arguments.concat(keywords.map { |kind, key| (:key == kind) ? "#{key}: OMITTED" : "#{key}:" })
		arguments << "**nil" if parameters.any? { |kind, _| :nokey == kind }
		arguments << "&#{block}"

		lines = values.filter_map { |key, value| "#{value} = ::Kernel.binding.local_variable_get(:#{key})" unless key == value }
		positional.zip(locals).each_with_index do |((kind, param), local), index|
			checked = check.(local, index, param.to_s)
			lines << ((:opt == kind) ? "#{checked} unless OMITTED.equal?(#{local})" : checked)
		end
		keywords.each_with_index do |(kind, key), index|
			checked = check.(values[key], positional.size + index, "#{key}:")
			lines << ((:key == kind) ? "#{checked} unless OMITTED.equal?(#{values[key]})" : checked)
		end

		required = locals.first(positional.count { |kind, _| :req == kind })
		optional = locals.drop(required.size)
		dispatch = lambda do |keyword_arguments|
			calls = (0..(optional.size)).map { |count| "#{callee}#{[*required, *optional.first(count), *keyword_arguments, "&#{block}"].join(', ')})" }
			branches = optional.zip(calls).map { |local, call| "OMITTED.equal?(#{local}) then #{call}" }
			branches.empty? ? calls.last : "if #{branches.join("\nelsif ")}\nelse #{calls.last}\nend"
		end

		given = keywords.map { |_, key| "#{key}: #{values[key]}" }
		omittable = keywords.filter_map { |kind, key| key if :key == kind }
		if omittable.empty?
			lines << "#{returned} = #{dispatch.(given)}"
		else
			lines << "#{returned} = if #{omittable.map { |key| "OMITTED.equal?(#{values[key]})" }.join(' || ')}"
			lines << "#{options} = {}"
			omittable.each { |key| lines << "#{options}[:#{key}] = #{values[key]} unless OMITTED.equal?(#{values[key]})" }
			lines << dispatch.([*keywords.filter_map { |kind, key| "#{key}: #{values[key]}" if :keyreq == kind }, "**#{options}"])
			lines << "else"
			lines << dispatch.(given)
			lines << "end"
		end
		lines << check.(returned, positional.size + keywords.size, "return")

		<<~RUBY
			# frozen_string_literal: true
			def #{name}(#{arguments.join(', ')})
				#{lines.join("\n")}
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

	# MRI also ends a class body that an exception is unwinding, so there the
	# watch tracks the exceptions raised since the sig and not rescued, and
	# leaves one in flight to propagate.
	WATCHED = ((RUBY_ENGINE == "ruby") ? [:end, :raise, :rescue] : [:end]).freeze

	# Watches the end of the class or module body the sig is written in, and
	# only until the next method is defined. A block, such as one passed to
	# `Class.new`, has no `end` event, and TruffleRuby has no TracePoint, so
	# there a sig with nothing after it is caught by the next sig.
	private def __literal_await_method__
		return if RUBY_ENGINE == "truffleruby"

		signature = @__literal_signature__
		return unless signature.site.label in /\A<(?:class|module):/ | "singleton class"

		owner = self
		thread = Thread.current
		unwinding = []
		@__literal_signature_watch__ = TracePoint.new(*WATCHED) do |tp|
			next unless thread.equal?(Thread.current)

			case tp.event
			in :raise
				unwinding << tp.raised_exception
			in :rescue
				unwinding.reject! { |error| error.equal?(tp.raised_exception) }
			in :end
				next unless Literal::EQUAL.bind_call(tp.self, owner)

				tp.disable
				Literal::INSTANCE_VARIABLE_SET.bind_call(owner, :@__literal_signature__, nil)
				Literal::INSTANCE_VARIABLE_SET.bind_call(owner, :@__literal_signature_watch__, nil)
				raise Literal::ArgumentError, "#{owner}: the sig at #{signature.site} has no method after it" if unwinding.empty?
			end
		end
		@__literal_signature_watch__.enable
	end

	# The watch holds the thread the class was defined on.
	private def __literal_stop_watching__
		@__literal_signature_watch__&.disable
		@__literal_signature_watch__ = nil
	end
end
