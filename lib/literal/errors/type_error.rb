# frozen_string_literal: true

class Literal::TypeError < TypeError
	INDENT = "  "

	include Literal::Error

	class Context
		attr_reader :receiver, :method, :label, :expected, :actual, :children

		def initialize(
			receiver: nil, # _Nilable(Object)
			method: nil, # _Nilable(String)
			label: nil, # _Nilable(String)
			expected: nil, # _Nilable(_Any)
			actual: nil, # _Nilable(_Any)
			parent: nil # _Nilable(Context)
		)
			@receiver = receiver
			@method = method
			@label = label
			@expected = expected
			@actual = actual
			@parent = parent
			@children = []
		end

		def descend(level = 0, &blk)
			yield self, level
			@children.each { |child| child.descend(level + 1, &blk) }
			nil
		end

		def fill_receiver(receiver:, method:, label: nil)
			@receiver = receiver
			@method = method
			@label = label
		end

		def add_child(expected: nil, actual: nil, **)
			child = self.class.new(expected:, actual:, parent: self, **)

			# A self-referential value would otherwise be diagnosed forever.
			if expected.respond_to?(:record_literal_type_errors) && !diagnosing?(expected, actual)
				expected.record_literal_type_errors(child)
			end

			@children << child
		end

		protected def diagnosing?(expected, actual)
			(Literal::EQUAL.bind_call(@expected, expected) && Literal::EQUAL.bind_call(@actual, actual)) ||
				!!@parent&.diagnosing?(expected, actual)
		end

		def to_h
			{
				receiver: @receiver,
				method: @method,
				label: @label,
				expected: @expected,
				actual: @actual,
				children: @children.map(&:to_h),
			}
		end

		alias to_hash to_h
	end

	def initialize(context:)
		@context = context

		super()
	end

	def message
		message = +"Type mismatch\n\n"

		@context.descend do |c, level|
			idt = INDENT * level
			if c.receiver || c.method
				message << idt
				message << Literal::CLASS.bind_call(c.receiver).inspect if c.receiver
				message << c.method if c.method
				message << " (from #{backtrace[1]})" if level.zero? && backtrace
				message << "\n"
			end
			if c.label
				idt << INDENT
				message << idt << c.label << "\n"
			end
			if c.children.empty?
				message << idt << "  Expected: #{inspect_object(c.expected)}\n"
				message << idt << "  Actual (#{Literal::CLASS.bind_call(c.actual)}): #{inspect_object(c.actual)}\n"
			end
		end
		message
	end

	def to_s
		message
	end

	def deconstruct_keys(keys)
		keys ? to_h.slice(*keys) : to_h
	end

	def to_h
		@context.to_h
	end

	private def inspect_object(object)
		Literal.implements?(object, :inspect) ? Literal::SEND.bind_call(object, :inspect) : Literal::INSPECT.bind_call(object)
	end
end
