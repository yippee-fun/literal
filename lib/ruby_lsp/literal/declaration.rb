# frozen_string_literal: true

module RubyLsp
	module Literal
		# A `prop` or `prop?` call, read statically from its arguments.
		Declaration = ::Data.define(:call, :name_node, :type, :options) do
			# A block may run against another receiver, as in
			# `Class.new(Literal::Data) { prop :name, String }`, so the props inside it
			# can't be attributed to the enclosing namespace.
			def self.hides_declarations?(call)
				call.block in Prism::BlockNode
			end

			def self.parse(call)
				return unless call.name in :prop | :prop?
				return unless call.receiver in nil | Prism::SelfNode

				positional = []
				options = {}

				call.arguments&.arguments&.each do |argument|
					case argument
					in Prism::KeywordHashNode
						argument.elements.each do |element|
							case element
							in Prism::AssocNode[key: Prism::SymbolNode[unescaped: String => key], value:]
								options[key] = value
							else
								# A splat or computed key may override any option given
								# before it, and supplies every option not given after it.
								options = Hash.new(element)
							end
						end
					else
						positional << argument
					end
				end

				case positional
				in [Prism::SymbolNode => name_node, Prism::Node => type, *]
					new(call:, name_node:, type:, options:)
				else
					nil
				end
			end

			def name = name_node.unescaped

			def optional? = :prop? == call.name

			# The visibility of a generated method, or nil when there is none or it
			# can't be known statically.
			def visibility(option, default: nil)
				case options[option]
				in nil
					default
				in Prism::SymbolNode[unescaped: "private" | "protected" | "public" => visibility]
					visibility.to_sym
				else
					nil
				end
			end

			def description
				case options["description"]
				in Prism::StringNode[unescaped: String => description]
					description
				else
					nil
				end
			end

			def signature
				location = type.location
				indentation = location.source_lines[location.start_line - 1][/\A\s*/]

				location.slice.lines.map { |line| line.delete_prefix(indentation) }.join
			end

			def documentation(comments)
				heading = optional? ? "**Type:** (optional)" : "**Type:**"

				[comments&.chomp, description, "#{heading}\n```ruby\n#{signature}\n```"]
					.reject { |section| section.nil? || section.empty? }
					.join("\n\n")
			end
		end
	end
end
