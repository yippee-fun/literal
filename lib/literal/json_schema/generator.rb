# frozen_string_literal: true

require "set"

class Literal::JSONSchema::Generator
	def initialize(context)
		@context = context
		@definitions = {}
		@definition_names = {}
		@reference_counts = Hash.new(0)
		@depth = 0
	end

	def schema(type, reference: true)
		type = type.materialize if type in Literal::Types::DeferredType

		root = @depth.zero?
		@depth += 1

		schema = if reference && !root && referenceable_type?(type)
			reference_schema(type)
		else
			@context.build_json_schema(type, generator: self)
		end

		root ? finalize_schema(schema) : schema
	ensure
		@depth -= 1
	end

	private def reference_schema(type)
		name = definition_name(type)
		@reference_counts[name] += 1

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

	private def json_pointer_unescape(value)
		value.gsub("~1", "/").gsub("~0", "~")
	end

	private def finalize_schema(schema)
		return schema unless @definitions.any?

		definitions = @definitions.compact
		definitions = definitions.to_h do |name, definition|
			[name, inline_single_use_refs(definition, definitions, Set[name])]
		end

		schema = inline_single_use_refs(schema, definitions, Set[])
		definitions = definitions.reject { |name, _| @reference_counts[name] == 1 }

		if definitions.any?
			schema.merge("$defs" => definitions)
		else
			schema
		end
	end

	private def inline_single_use_refs(schema, definitions, stack)
		case schema
		when Hash
			ref = definition_ref(schema)

			if ref && @reference_counts[ref] == 1 && !stack.include?(ref)
				return inline_single_use_refs(definitions.fetch(ref), definitions, stack | Set[ref])
			end

			schema.to_h do |key, value|
				[key, inline_single_use_refs(value, definitions, stack)]
			end
		when Array
			schema.map { |value| inline_single_use_refs(value, definitions, stack) }
		else
			schema
		end
	end

	private def definition_ref(schema)
		return unless schema.keys == ["$ref"]

		ref = schema.fetch("$ref")
		prefix = "#/$defs/"

		if ref.start_with?(prefix)
			json_pointer_unescape(ref.delete_prefix(prefix))
		end
	end

	private def structure_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Class === type && type < Literal::DataStructure
	end

	private def map_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Literal::Types::MapType === type
	end

	private def array_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Literal::Types::ArrayType === type
	end

	private def hash_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Literal::Types::HashType === type
	end

	private def tuple_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		Literal::Types::TupleType === type
	end

	private def referenceable_type?(type)
		structure_type?(type) ||
			map_type?(type) ||
			array_type?(type) ||
			hash_type?(type) ||
			tuple_type?(type)
	end
end
