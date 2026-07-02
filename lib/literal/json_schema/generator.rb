# frozen_string_literal: true

# Generates a JSON Schema for a type, extracting shared and recursive schemas
# into "$defs". Definitions are created lazily: every node is built inline
# until the walk proves a definition is needed — either a back-edge to a node
# still being built (recursion) or a second occurrence of a node that was
# already built (sharing). Definitions are therefore referenced at least twice
# or cyclically, with one exception: a serializer may copy a node to attach
# site-specific keywords (such as a property description), in which case the
# copy stays inline and a later promotion can leave a definition with a single
# reference. The output is still correct, just not maximally compact.
class Literal::JSONSchema::Generator
	def initialize(context)
		@context = context
		@definitions = {}
		@promoted = {}.compare_by_identity
		@completed = {}.compare_by_identity
		@in_progress = {}.compare_by_identity
		@generated = false
	end

	# Single-shot entry point. A generator accumulates definitions for exactly
	# one root type; reusing it would leak one schema's definitions into another.
	def generate(type)
		raise Literal::ArgumentError, "This generator has already been used. Create a new generator for each schema." if @generated
		@generated = true

		unless @context.serializable_type?(type)
			raise @context.unserializable_type_error(type)
		end

		result = schema(type)
		return result if @definitions.empty?

		# A recursive root comes back as a bare reference to its own definition.
		# Inline the definition body at the root as well, since many JSON Schema
		# consumers reject a root-level "$ref".
		if (name = own_reference_name(result))
			result = @definitions.fetch(name)
		end

		result.merge("$defs" => @definitions)
	end

	# Called by serializers for child types. With reference: false the caller
	# needs the schema body rather than a reference — for example to merge a
	# discriminator into it — so nothing is memoized for reuse.
	def schema(type, reference: true)
		type = type.materialize if type in Literal::Types::DeferredType

		if @in_progress.key?(type)
			reference_to(promote(type))
		elsif !reference
			build(type, memoize: false)
		elsif (name = @promoted[type])
			reference_to(name)
		elsif @completed.key?(type)
			reference_to(promote(type))
		else
			build(type, memoize: true)
		end
	end

	private def build(type, memoize:)
		@in_progress[type] = true
		node = @context.build_json_schema(type, generator: self)

		if (name = @promoted[type])
			# A descendant back-edged into this node while it was being built.
			@definitions[name] = node if @definitions[name].nil?
			memoize ? reference_to(name) : node
		else
			@completed[type] = node if memoize && Hash === node && @context.referenceable_type?(type)
			node
		end
	ensure
		@in_progress.delete(type)
	end

	# Assign the type a definition name. If its schema was already emitted
	# inline, move the body into the definition and turn the original
	# occurrence into a reference in place.
	private def promote(type)
		@promoted[type] ||= begin
			name = @definitions.length.to_s(36)

			if (node = @completed.delete(type))
				@definitions[name] = node.dup
				node.replace(reference_to(name))
			else
				@definitions[name] = nil
			end

			name
		end
	end

	private def reference_to(name)
		{ "$ref" => "#/$defs/#{name}" }
	end

	private def own_reference_name(schema)
		return unless Hash === schema && schema.keys == ["$ref"]

		reference = schema.fetch("$ref")
		reference.delete_prefix("#/$defs/") if reference.start_with?("#/$defs/")
	end
end
