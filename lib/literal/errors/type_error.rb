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

		def add_child(expected: nil, **kwargs)
			child = self.class.new(expected:, **kwargs)
			expected.record_literal_type_errors(child) if expected.respond_to?(:record_literal_type_errors)
			@children << child
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
				message << c.receiver.class.inspect if c.receiver
				message << c.method if c.method
				message << " (from #{backtrace[1]})" if level.zero?
				message << "\n"
			end
			if c.label
				idt << INDENT
				message << idt << c.label << "\n"
			end
			if c.expected && c.children.empty?
				message << idt << "  Expected: #{c.expected.inspect}\n"
				message << idt << "  Actual (#{c.actual.class}): #{c.actual.inspect}\n"
			end
		end
		message
	end

	def deconstruct_keys(keys)
		to_h.slice(*keys)
	end

	def to_h
		@context.to_h
	end
end
