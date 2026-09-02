# frozen_string_literal: true

# @api private
#
# One declared check. A block is handed values, never the object, which is
# what lets construction and `Draft#check` run the same check and get the same
# answer. Its keyword parameters name the properties it reads.
#
# The predicate form (`check`) carries the property a failure is filed against
# and the message; an anonymous block (`it`, `_1`, a Symbol proc) reads that
# property alone. The reporting form (`checks`) carries neither: the block
# takes a reporter first and files whatever it finds.
class Literal::Checks::Check
	TEMPLATE = /%\{([[:word:]]+)\}/

	def initialize(owner:, block:, prop: nil, message: nil, reporting: false)
		@owner = owner
		@prop = prop
		@message = message
		@block = block
		@reporting = reporting
		__check_prop__
		@anonymous, @keyword_reads = __reads__
		@reads = [*(@prop if @anonymous), *@keyword_reads].uniq.freeze

		unless @reporting
			__check_message__
			@message = -@message
		end

		freeze
	end

	attr_reader :prop, :message, :reads

	# Writing a property can only change an outcome that reads it; where the
	# error is filed has no bearing on whether it happens.
	def depends_on?(name)
		@reads.include?(name)
	end

	# Here the property reported against does count: an error needs somewhere
	# to go. A reporting check names its properties only as it runs.
	def applies_to?(names)
		(@prop.nil? || names.include?(@prop)) && @reads.all? { |name| names.include?(name) }
	end

	# `shape` is the class being checked — a slice of the owner, or the owner
	# itself — so a reporting check files against what that class has.
	def run(shape, errors, &read)
		keywords = @keyword_reads.to_h { |name| [name, read.call(name)] }

		# An undefinable property that was not given holds no value, so the check
		# does not apply. A nilable one holds nil, and still does.
		return if keywords.each_value.any? { |value| Literal::Undefined == value }

		if @reporting
			@block.call(Literal::Checks::Reporter.new(shape, errors), **keywords)
			return
		end

		if @anonymous
			value = read.call(@prop)
			return if Literal::Undefined == value
			return if @block.call(value, **keywords)

			keywords[@prop] = value
		else
			return if @block.call(**keywords)
		end

		errors.add(@prop, message_for(keywords))
	end

	private def message_for(values)
		return @message unless TEMPLATE.match?(@message)

		@message.gsub(TEMPLATE) { values.fetch(Regexp.last_match(1).to_sym).to_s }
	end

	# Checked at declaration: a typo left latent would raise out of every
	# construction of the shape on the check's first failure.
	private def __check_prop__
		return if @prop.nil? || @owner.literal_properties[@prop]

		raise Literal::ArgumentError.new(
			"#{__owner_name__} has no #{@prop.inspect} property for a check to report against"
		)
	end

	private def __check_message__
		unless String === @message
			raise Literal::ArgumentError.new(
				"A check's message is a String, got #{@message.class}"
			)
		end

		@message.scan(TEMPLATE) do |(name)|
			next if @reads.include?(name.to_sym)

			raise Literal::ArgumentError.new(
				"A message's %{} slots name the properties its check reads, and this one does not read #{name.to_sym.inspect}"
			)
		end
	end

	private def __reads__
		parameters = @block.parameters

		# A block reading nothing is a constant, not a check — and on Ruby 3.3 a
		# bare `it` also reports no parameters, so accepting zero would let it
		# through to raise a NameError out of construction there.
		if parameters.empty?
			raise Literal::ArgumentError.new(
				"A check reads the property each of its keyword parameters names, so its block takes at least one: write `{ |min:| ... }`"
			)
		end

		@reporting ? __reporting_reads__(parameters) : __predicate_reads__(parameters)
	end

	# An anonymous block — `it` (which Ruby 3.4 reflects as [[:opt, nil]] and
	# 3.5 as [[:opt]]), a lone `_1`, or a Symbol proc (`&:positive?`, which
	# reflects as [[:req], [:rest]] — a shape no source-written signature has)
	# reads the property the failure is filed against. Every named read is a
	# keyword, the pinned property included, so a block never mixes the two.
	private def __predicate_reads__(parameters)
		if parameters in [[:opt]] | [[:opt, nil]] | [[:opt, :_1]] | [[:req], [:rest]]
			unless @prop
				raise Literal::ArgumentError.new(
					"A whole-value check has no property for an anonymous block to read, so name what it reads: write `{ |min:, max:| ... }`"
				)
			end

			return [true, [].freeze]
		end

		keywords = parameters.map do |kind, name|
			case kind
			in :keyreq | :key
				__check_read__(name)
			in :req | :opt
				raise Literal::ArgumentError.new(
					"A check reads its properties as keywords: write `{ |min:, max:| ... }`, not `{ |min, max| ... }`; a bare `it` reads the property the failure is filed against"
				)
			else
				raise Literal::ArgumentError.new(
					"A check reads one property per parameter, so it cannot take #{kind.inspect}"
				)
			end
		end

		[false, keywords.freeze]
	end

	# The first parameter is the reporter; every read is a keyword, which is
	# what keeps the two apart at a glance.
	private def __reporting_reads__(parameters)
		unless parameters.first in [:req | :opt, Symbol]
			raise Literal::ArgumentError.new(
				"A reporting check takes the reporter first, then the properties it reads as keywords: write `{ |errors, min:, max:| ... }`"
			)
		end

		keywords = parameters.drop(1).map do |kind, name|
			case kind
			in :keyreq | :key
				__check_read__(name)
			else
				raise Literal::ArgumentError.new(
					"A reporting check reads its properties as keywords, so it cannot take #{kind.inspect}: write `{ |errors, min:, max:| ... }`"
				)
			end
		end

		if keywords.empty?
			raise Literal::ArgumentError.new(
				"A reporting check reads the property each of its keyword parameters names, so it takes at least one: write `{ |errors, min:| ... }`"
			)
		end

		[false, keywords.freeze]
	end

	private def __check_read__(name)
		unless @owner.literal_properties[name]
			raise Literal::ArgumentError.new(
				"#{__owner_name__} has no #{name.inspect} property for a check to read"
			)
		end

		name
	end

	private def __owner_name__
		@owner.name || "This shape"
	end
end
