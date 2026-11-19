# frozen_string_literal: true

require "ruby_lsp/addon"
require "literal/version"
require_relative "declaration"
require_relative "document_symbol"

# ruby-lsp 0.27 replaces RubyIndexer with Rubydex, which has no API for
# indexing DSLs yet.
require_relative "indexing_enhancement" if defined?(RubyIndexer::Enhancement)

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
				::Literal::VERSION
			end

			def create_document_symbol_listener(response_builder, dispatcher)
				DocumentSymbol.new(response_builder, dispatcher)
			end
		end
	end
end
