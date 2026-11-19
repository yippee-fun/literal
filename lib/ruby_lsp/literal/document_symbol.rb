# frozen_string_literal: true

module RubyLsp
	module Literal
		# Lists each prop in the outline, under the class or module that declares it.
		class DocumentSymbol
			include RubyLsp::Requests::Support::Common

			def initialize(response_builder, dispatcher)
				@response_builder = response_builder
				@hidden_parents = []

				dispatcher.register(self, :on_call_node_enter, :on_call_node_leave)
			end

			def on_call_node_enter(node)
				parent = @response_builder.last
				append(node, parent) if RubyLsp::Interface::DocumentSymbol === parent && !@hidden_parents.last.equal?(parent)
				@hidden_parents << parent if Declaration.hides_declarations?(node)
			end

			def on_call_node_leave(node)
				@hidden_parents.pop if Declaration.hides_declarations?(node)
			end

			private def append(node, parent)
				declaration = Declaration.parse(node) or return
				type = declaration.type.slice.lines.map(&:strip).join(" ")

				parent.children << RubyLsp::Interface::DocumentSymbol.new(
					name: declaration.name,
					detail: declaration.optional? ? "#{type} (optional)" : type,
					kind: RubyLsp::Constant::SymbolKind::PROPERTY,
					range: range_from_node(node),
					selection_range: range_from_node(declaration.name_node),
				)
			end
		end
	end
end
