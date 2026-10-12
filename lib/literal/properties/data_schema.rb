# frozen_string_literal: true

class Literal::Properties::DataSchema < Literal::Properties::Schema
	def generate_after_initializer(buffer = +"")
		super
		buffer << "  freeze\n"
	end

	# Follows the initializer's lifecycle, except that only the changed values
	# are coerced, sealed and type checked: the carried-over ones are final.
	def generate_with(buffer = +"", checked: false)
		sorted_properties = @sorted_properties
		n = sorted_properties.size

		buffer << "alias_method(:with, :with) if method_defined?(:with, false)\n" \
			"def with(**changes)\n" \
			"  return self if changes.empty?\n" \
			"  properties = self.class.literal_properties\n" \
			"  changes.each_key do |name|\n" \
			"    properties[name] || raise(NameError.new(\"unknown attribute: \#{name.inspect} for \#{self.class}\"))\n" \
			"  end\n"

		i = 0
		while i < n
			property = sorted_properties[i]
			key = property.name.inspect

			buffer << "  if changes.key?(" << key << ")\n" \
				"    v" << i.to_s << " = changes[" << key << "]\n" \
				"    __property__ = properties[" << key << "]\n"

			if property.coercion
				buffer << "    v" << i.to_s << " = __property__.coerce(v" << i.to_s << ", context: self)\n"
			end

			if property.seal
				buffer << "    v" << i.to_s << " = __property__.seal.call(v" << i.to_s << ")\n"
			end

			buffer << "    __property__.check_with(self, v" << i.to_s << ")\n" \
				"  else\n" \
				"    v" << i.to_s << " = @" << property.name.name << "\n" \
				"  end\n"
			i += 1
		end

		buffer << "  copy = self.class.allocate\n" \
			"  copy.__send__(:__literal_assign_with__"
		i = 0
		while i < n
			buffer << ", v" << i.to_s
			i += 1
		end
		buffer << ")\n" \
			"  copy.__send__(:after_initialize) if copy.respond_to?(:after_initialize, true)\n" \
			"  copy.freeze\n"
		buffer << "  copy.__send__(:__literal_run_checks__)\n" if checked
		buffer << "  copy\n" \
			"rescue Literal::TypeError => error\n" \
			"  error.set_backtrace(caller(1))\n" \
			"  raise\n" \
			"end\n"

		buffer << "alias_method(:__literal_assign_with__, :__literal_assign_with__) if private_method_defined?(:__literal_assign_with__, false)\n" \
			"private def __literal_assign_with__("
		i = 0
		while i < n
			buffer << ", " if i > 0
			buffer << "v" << i.to_s
			i += 1
		end
		buffer << ")\n"
		i = 0
		while i < n
			buffer << "  @" << sorted_properties[i].name.name << " = v" << i.to_s << "\n"
			i += 1
		end
		buffer << "end\n"
	end
end
