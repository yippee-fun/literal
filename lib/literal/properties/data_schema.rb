# frozen_string_literal: true

class Literal::Properties::DataSchema < Literal::Properties::Schema
	def generate_after_initializer(buffer = +"")
		super
		buffer << "  ::Literal::FREEZE.bind_call(self)\n"
	end

	# Builds the copy as the initializer would, in property order and against
	# the copy, so defaults and coercions see its earlier properties. Changed
	# values are resolved, coerced and sealed; carried-over ones are final, but
	# every value is type checked, as constructing from props does.
	def generate_with(buffer = +"", checked: false)
		sorted_properties = @sorted_properties
		n = sorted_properties.size

		buffer << "alias_method(:with, :with) if method_defined?(:with, false)\n" \
			"def with(**changes)\n" \
			"  return self if changes.empty?\n" \
			"  shape = ::Literal::CLASS.bind_call(self)\n" \
			"  changes.each_key do |name|\n" \
			"    PROPERTIES[name] || ::Kernel.raise(::NameError.new(\"unknown attribute: \#{name.inspect} for \#{shape}\"))\n" \
			"  end\n" \
			"  assigned = false\n" \
			"  shape.__send__(:__literal_constructing__) do\n" \
			"    copy = shape.allocate\n" \
			"    ::Literal::INSTANCE_EXEC.bind_call(copy"

		i = 0
		while i < n
			buffer << ", @" << sorted_properties[i].name.name
			i += 1
		end

		buffer << ") do |"

		i = 0
		while i < n
			buffer << ", " if i > 0
			buffer << "v" << i.to_s
			i += 1
		end

		buffer << "|\n"

		i = 0
		while i < n
			property = sorted_properties[i]
			key = ":#{property.name.name}"
			var = "v#{i}"

			buffer << "  __property__ = PROPERTIES[" << key << "]\n"
			buffer << "  if changes.key?(" << key << ")\n"
			buffer << "    " << var << " = changes[" << key << "]\n"

			# Splats have no sentinel: the initializer always receives a value.
			if property.default? && !property.splat? && !property.double_splat?
				buffer << "    if " << (property.block? ? "nil" : "::Literal::Undefined") << " == " << var << "\n"
				buffer << "      " << var << " = __property__.default_value(self)\n"
				buffer << "    end\n"
			end

			if property.coercion
				buffer << "    " << var << " = __property__.coerce(" << var << ", context: self)\n"
			end

			if property.seal
				buffer << "    " << var << " = __property__.apply_seal(" << var << ")\n"
			end

			buffer << "  end\n"
			buffer << "  __property__.check_with(self, " << var << ")\n"
			buffer << "  @" << property.name.name << " = " << (property.const? ? "__property__.default" : var) << "\n"
			i += 1
		end

		# Like the initializer's `else`, so a type error raised by an
		# after_initialize or a check keeps its own backtrace.
		buffer << "  assigned = true\n"
		generate_after_initializer(buffer)
		buffer << "  __literal_run_checks__\n" if checked

		buffer << "    end\n" \
			"    copy\n" \
			"  end\n" \
			"rescue ::Literal::TypeError => error\n" \
			"  ::Kernel.raise if assigned\n" \
			"  error.set_backtrace(::Literal::Error.trim(::Kernel.caller_locations(1)))\n" \
			"  ::Kernel.raise\n" \
			"end\n"
	end
end
