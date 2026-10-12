# frozen_string_literal: true

class Literal::Properties::DataSchema < Literal::Properties::Schema
	def generate_after_initializer(buffer = +"")
		super
		buffer << "  freeze\n"
	end

	# Follows the initializer's lifecycle on a fresh copy, in property order, so
	# defaults and coercions see the copy's earlier properties as they would in
	# the initializer. Only the changed values are resolved, coerced, sealed and
	# type checked: the carried-over ones are final.
	def generate_with(buffer = +"", checked: false)
		sorted_properties = @sorted_properties
		n = sorted_properties.size

		buffer << "alias_method(:with, :with) if method_defined?(:with, false)\n" \
			"def with(**changes)\n" \
			"  return self if changes.empty?\n" \
			"  properties = self.class.literal_properties\n" \
			"  changes.each_key do |name|\n" \
			"    properties[name] || raise(NameError.new(\"unknown attribute: \#{name.inspect} for \#{self.class}\"))\n" \
			"  end\n" \
			"  copy = self.class.allocate\n" \
			"  copy.__send__(:__literal_with__, changes"
		i = 0
		while i < n
			buffer << ", @" << sorted_properties[i].name.name
			i += 1
		end
		buffer << ")\n" \
			"  copy\n" \
			"rescue Literal::TypeError => error\n" \
			"  error.set_backtrace(caller(1))\n" \
			"  raise\n" \
			"end\n"

		buffer << "alias_method(:__literal_with__, :__literal_with__) if private_method_defined?(:__literal_with__, false)\n" \
			"private def __literal_with__(changes"
		i = 0
		while i < n
			buffer << ", v" << i.to_s
			i += 1
		end
		buffer << ")\n" \
			"  __properties__ = self.class.literal_properties.properties_index\n"

		i = 0
		while i < n
			property = sorted_properties[i]
			key = property.name.inspect
			var = "v#{i}"

			buffer << "  if changes.key?(" << key << ")\n"
			buffer << "    " << var << " = changes[" << key << "]\n"
			buffer << "    __property__ = __properties__[" << key << "]\n"

			# Splats have no sentinel: the initializer always receives a value.
			if property.default? && !property.splat? && !property.double_splat?
				buffer << "    if " << ((property.kind == :&) ? "nil" : "Literal::Undefined") << " == " << var << "\n"
				buffer << "      " << var << " = __property__.default_value(self)\n"
				buffer << "    end\n"
			end

			if property.coercion
				buffer << "    " << var << " = __property__.coerce(" << var << ", context: self)\n"
			end

			if property.seal
				buffer << "    " << var << " = __property__.seal.call(" << var << ")\n"
			end

			buffer << "    __property__.check_with(self, " << var << ")\n"
			buffer << "  end\n"
			buffer << "  @" << property.name.name << " = " << var << "\n"
			i += 1
		end

		generate_after_initializer(buffer)
		buffer << "  __literal_run_checks__\n" if checked
		buffer << "end\n"
	end
end
