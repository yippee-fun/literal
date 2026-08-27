# frozen_string_literal: true

# @api private
#
# The predicate is handed values, never the object, which is what lets
# construction and `validate` run the same stipulation and get the same answer.
class Literal::Validations::Stipulation
	NUMBERED = /\A_\d+\z/
	TEMPLATE = /%\{([[:word:]]+)\}/

	def initialize(owner:, prop:, message:, predicate:)
		@prop = prop
		@message = message
		@predicate = predicate
		__check_prop__(owner)
		@positional_reads, @keyword_reads = __reads__(owner)
		@reads = (@positional_reads + @keyword_reads).freeze
		__check_message__
		# Our own frozen copy, or the caller can mutate the string after the
		# check and a slot fails to fill on the first value that fails.
		@message = -@message
		freeze
	end

	attr_reader :prop, :message, :reads

	# Writing a property can only change an outcome that reads it; where the
	# error is filed has no bearing on whether it happens.
	def depends_on?(name)
		@reads.include?(name)
	end

	# Here the property reported against does count: an error needs somewhere
	# to go.
	def applies_to?(names)
		(@prop.nil? || names.include?(@prop)) && @reads.all? { |name| names.include?(name) }
	end

	def check(errors, &read)
		positional = []

		@positional_reads.each do |name|
			value = read.call(name)

			# An undefinable property that was not given holds no value, so the
			# stipulation does not apply. A nilable one holds nil, and still does.
			return true if Literal::Undefined == value

			positional << value
		end

		keywords = {}

		@keyword_reads.each do |name|
			value = read.call(name)

			return true if Literal::Undefined == value

			keywords[name] = value
		end

		return true if @predicate.call(*positional, **keywords)

		errors.add(@prop, message_for(positional, keywords))
		false
	end

	private def message_for(positional, keywords)
		return @message unless TEMPLATE.match?(@message)

		by_name = @positional_reads.zip(positional).to_h.merge!(keywords)

		@message.gsub(TEMPLATE) { by_name.fetch(Regexp.last_match(1).to_sym).to_s }
	end

	# Checked at declaration: a typo left latent would raise out of every
	# construction of the shape on the stipulation's first failure.
	private def __check_prop__(owner)
		return if @prop.nil? || owner.literal_properties[@prop]

		raise Literal::ArgumentError.new(
			"#{owner.name || 'This shape'} has no #{@prop.inspect} property for a stipulation to report against"
		)
	end

	private def __check_message__
		unless String === @message
			raise Literal::ArgumentError.new(
				"A stipulation's message is a String, got #{@message.class}"
			)
		end

		@message.scan(TEMPLATE) do |(name)|
			next if @reads.include?(name.to_sym)

			raise Literal::ArgumentError.new(
				"A message's %{} slots name the properties its stipulation reads, and this one does not read #{name.to_sym.inspect}"
			)
		end
	end

	private def __reads__(owner)
		properties = owner.literal_properties
		parameters = @predicate.parameters

		# A predicate reading nothing is a constant, not a rule — and on Ruby
		# 3.3 a bare `it` also reports no parameters, so accepting zero would
		# let it through to raise a NameError out of construction there.
		if parameters.empty?
			raise Literal::ArgumentError.new(
				"A stipulation reads the property each of its parameters names, so its predicate takes at least one: write `{ |min| ... }`"
			)
		end

		# `it` or a lone `_1`: a single anonymous parameter reads the property
		# the failure is filed against.
		if parameters in [[:opt]] | [[:opt, :_1]]
			unless @prop
				raise Literal::ArgumentError.new(
					"A whole-value stipulation has no property for `it` to read, so name what it reads: write `{ |min, max| ... }`"
				)
			end

			return [[@prop].freeze, [].freeze]
		end

		positional = []
		keywords = []

		# A keyword parameter reads the same way a positional one does — it is
		# how a reserved-word property stays spellable: `{ |end:| ... }` declares
		# where `{ |end| ... }` cannot, and the body reads the value with
		# `binding.local_variable_get(:end)`.
		parameters.each do |kind, name|
			case kind
			in :req | :opt
				positional << __check_read__(owner, properties, __resolve__(name))
			in :keyreq | :key
				keywords << __check_read__(owner, properties, name)
			else
				raise Literal::ArgumentError.new(
					"A stipulation reads one property per parameter, so it cannot take #{kind.inspect}"
				)
			end
		end

		[positional.freeze, keywords.freeze]
	end

	private def __check_read__(owner, properties, name)
		unless properties[name]
			raise Literal::ArgumentError.new(
				"#{owner.name || 'This shape'} has no #{name.inspect} property for a stipulation to read"
			)
		end

		name
	end

	private def __resolve__(name)
		if name.nil? || NUMBERED.match?(name)
			raise Literal::ArgumentError.new(
				"A stipulation reading more than one property names each read with a parameter: write `{ |min, max| ... }`, not a Symbol proc or numbered parameters"
			)
		end

		name
	end
end
