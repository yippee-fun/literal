# frozen_string_literal: true

# @api private
# The procs coercions and seals are built from. Made here rather than on a
# coercion or seal, so a proc's self is a module, which lets
# Ractor.make_shareable accept it.
module Literal::Pipeline
	extend self

	def proc_from(callable)
		case callable
		in ::Proc
			callable
		else
			callable.respond_to?(:to_proc) ? callable.to_proc : proc { |value| callable.call(value) }
		end
	end

	# instance_exec, not call: a coercion runs against the object being
	# constructed, and each stage should see that context the same way an
	# uncomposed block would.
	def compose(first, second)
		proc { |value| instance_exec(instance_exec(value, &first), &second) }
	end

	# Ruby only makes a proc shareable once what it captures is, and won't
	# reach into it, so what a proc made here captures is shared first.
	def make_shareable(proc)
		if __FILE__ == proc.source_location&.first
			binding = proc.binding

			binding.local_variables.each do |name|
				case (captured = binding.local_variable_get(name))
				in ::Proc
					make_shareable(captured)
				else
					Ractor.make_shareable(captured)
				end
			end
		end

		Ractor.make_shareable(proc)
	end
end
