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
end
