# frozen_string_literal: true

module RubyLsp
	module Literal
		class IndexingEnhancement < RubyIndexer::Enhancement
			# ruby-lsp 0.26.5 added a leading configuration argument to index entries.
			ENTRIES_TAKE_CONFIGURATION = (RubyIndexer::Entry::InstanceVariable.instance_method(:initialize).parameters in [[:req, :configuration], *])

			# Only a direct superclass is visible while indexing, so a subclass of a
			# subclass gets no default readers or writers.
			DEFAULT_VISIBILITIES = {
				"Literal::Struct" => { "reader" => :public, "writer" => :public },
				"Literal::Data" => { "reader" => :public },
				"Literal::Enum" => { "reader" => :public },
			}.freeze

			def initialize(listener)
				super
				@hidden_owners = []
			end

			def on_call_node_enter(node)
				owner = @listener.current_owner
				index(node, owner) if owner && !@hidden_owners.last.equal?(owner)
				@hidden_owners << owner if Declaration.hides_declarations?(node)
			end

			def on_call_node_leave(node)
				@hidden_owners.pop if Declaration.hides_declarations?(node)
			end

			private def index(node, owner)
				declaration = Declaration.parse(node) or return

				name = declaration.name
				location = node.location
				comments = @listener.instance_exec { collect_comments(node) }
				documentation = declaration.documentation(comments)

				@listener.instance_exec do
					entry_arguments = [
						"@#{name}",
						@uri,
						RubyIndexer::Location.from_prism_location(location, @code_units_cache),
						documentation,
						owner,
					]

					entry_arguments.unshift(@index.configuration) if ENTRIES_TAKE_CONFIGURATION

					@index.add(RubyIndexer::Entry::InstanceVariable.new(*entry_arguments))
				end

				defaults = DEFAULT_VISIBILITIES.fetch(superclass_name(owner), {})

				if (visibility = declaration.visibility("reader", default: defaults["reader"]))
					@listener.add_method(name, location, [
						RubyIndexer::Entry::Signature.new([]),
					], visibility:, comments: documentation)
				end

				if (visibility = declaration.visibility("writer", default: defaults["writer"]))
					@listener.add_method("#{name}=", location, [
						RubyIndexer::Entry::Signature.new([
							RubyIndexer::Entry::RequiredParameter.new(name: :value),
						]),
					], visibility:, comments: documentation)
				end

				if (visibility = declaration.visibility("predicate"))
					@listener.add_method("#{name}?", location, [
						RubyIndexer::Entry::Signature.new([]),
					], visibility:, comments: documentation)
				end
			end

			private def superclass_name(owner)
				case owner
				in RubyIndexer::Entry::Class
					owner.parent_class&.delete_prefix("::")
				else
					nil
				end
			end
		end
	end
end
