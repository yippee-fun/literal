# frozen_string_literal: true

class Literal::JSONSchema::Generator
	def initialize(context)
		@context = context
		@definitions = {}
		@definition_names = {}
		@depth = 0
	end

	def schema(type, reference: true)
		type = type.materialize if type in Literal::Types::DeferredType

		root = @depth.zero?
		@depth += 1

		schema = if reference && !root && named_structure_type?(type)
			reference_schema(type)
		else
			@context.build_json_schema(type, generator: self)
		end

		if root && @definitions.any?
			schema.merge("$defs" => @definitions.compact)
		else
			schema
		end
	ensure
		@depth -= 1
	end

	private def reference_schema(type)
		name = definition_name(type)

		unless @definitions.key?(name)
			@definitions[name] = nil
			@definitions[name] = schema(type, reference: false)
		end

		{ "$ref" => "#/$defs/#{json_pointer_escape(name)}" }
	end

	private def definition_name(type)
		@definition_names[type] ||= @definition_names.length.to_s(36)
	end

	private def json_pointer_escape(value)
		value.gsub("~", "~0").gsub("/", "~1")
	end

	private def structure_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Class === type && type < Literal::DataStructure
	end

	private def named_structure_type?(type)
		structure_type?(type) && type.name
	end
end
