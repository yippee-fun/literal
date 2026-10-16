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

	def sig(*positional, **keywords)
		if @__literal_signature__
			raise Literal::ArgumentError, "#{self}: the sig at #{@__literal_signature__.site} has no method after it"
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
		parameters = owner.instance_method(name).parameters
		__literal_refuse_mismatch__(signature, parameters, "#{self}#{singleton ? '.' : '#'}#{name}")

		visibility = __literal_visibility__(owner, name)
		unsigned = :"__literal_unsigned_#{name.object_id}__"
		owner.alias_method(unsigned, name)
		owner.__send__(:private, unsigned)

		checker = Module.new
		keywords = signature.keywords.values_at(*__literal_keywords__(parameters))
		checker.const_set(:TYPES, [*signature.positional, *keywords, signature.returns].freeze)
		code = __literal_checker_code__(name, unsigned, parameters, singleton ? "#{self}.#{name}" : "##{name}", singleton)
		# An explicit path, so every engine attributes these frames to Literal.
		checker.module_eval(code, __FILE__, __LINE__)

		owner.define_method(name, checker.instance_method(name))
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

		read = -> (key) { Literal::Property::RUBY_KEYWORDS.key?(key) ? "binding.local_variable_get(:#{key})" : key.to_s }
		check = lambda do |value, index, label|
			"::Literal.check(#{value}, TYPES[#{index}]) { |c| c.fill_receiver(receiver: #{receiver}, method: #{method.inspect}, label: #{label.inspect}) }"
		end

		arguments = Array.new(required) { |index| "__literal_arg_#{index}__" }
		arguments << "*__literal_optional__" if positional.size > required
		arguments.concat(keywords.map { |key| "#{key}:" })
		arguments << "**__literal_options__" if options.any?
		arguments << "&"

		checks = Array.new(required) { |index| check.("__literal_arg_#{index}__", index, positional[index].to_s) }
		(required...(positional.size)).each_with_index do |index, offset|
			checks << "#{check.("__literal_optional__[#{offset}]", index, positional[index].to_s)} if __literal_optional__.size > #{offset}"
		end
		keywords.each { |key| checks << check.(read.(key), positional.size + keyword_order.index(key), "#{key}:") }
		options.each do |key|
			checks << "#{check.("__literal_options__[:#{key}]", positional.size + keyword_order.index(key), "#{key}:")} if __literal_options__.key?(:#{key})"
		end

		call = Array.new(required) { |index| "__literal_arg_#{index}__" }
		call << "*__literal_optional__" if positional.size > required
		call.concat(keywords.map { |key| "#{key}: #{read.(key)}" })
		call << "**__literal_options__" if options.any?
		call << "&"

		<<~RUBY
			# frozen_string_literal: true
			def #{name}(#{arguments.join(', ')})
				#{checks.join("\n")}
				__literal_returned__ = #{unsigned}(#{call.join(', ')})
				#{check.('__literal_returned__', positional.size + keyword_order.size, 'return')}
				__literal_returned__
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
			next unless tp.self.equal?(owner)

			tp.disable
			raise Literal::ArgumentError, "#{owner}: the sig at #{signature.site} has no method after it"
		end
		@__literal_signature_watch__.enable
	end
end
