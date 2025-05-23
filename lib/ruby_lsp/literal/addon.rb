# frozen_string_literal: true

require "ruby_lsp/addon"

module RubyLsp
	module Literal
		class Addon < ::RubyLsp::Addon
			def activate(global_state, message_queue)
			end

			def deactivate
			end

			def name
				"Literal"
			end

			def version
				"0.1.0"
			end
		end

		class MyIndexingEnhancement < RubyIndexer::Enhancement
			def on_call_node_enter(node)
				name = node.name
				owner = @listener.current_owner
				location = node.location
				arguments = node.arguments&.arguments

				return unless owner
				return unless :prop == name

				args = arguments&.reject { |it| it.is_a?(Prism::KeywordHashNode) }
				kwargs = arguments.find { |it| it.is_a?(Prism::KeywordHashNode) }&.elements.to_h do |element|
					case element
					in { key: Prism::SymbolNode[unescaped: String => key], value: value }
						[key, value]
					end
				end

				case args
				in [Prism::SymbolNode[unescaped: String => prop_name], *]
					@listener.instance_exec do
						@index.add(RubyIndexer::Entry::InstanceVariable.new(
							"@#{prop_name}",
							@uri,
							RubyIndexer::Location.from_prism_location(node.location, @code_units_cache),
							collect_comments(node),
							owner,
						))
					end

					if kwargs["reader"] in Prism::SymbolNode[unescaped: "private" | "protected" | "public" => visibility]
						@listener.add_method(prop_name, location, [
							RubyIndexer::Entry::Signature.new([]),
						], visibility: visibility.to_sym)
					end

					if kwargs["writer"] in Prism::SymbolNode[unescaped: "private" | "protected" | "public" => visibility]
						@listener.add_method("#{prop_name}=", location, [
							RubyIndexer::Entry::Signature.new([
								RubyIndexer::Entry::RequiredParameter.new(name: "value"),
							]),
						], visibility: visibility.to_sym)
					end
				end
			end
		end
	end
end
