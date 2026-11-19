# frozen_string_literal: true

# ruby-lsp is a development dependency, so it isn't available in every environment.
ruby_lsp_available = begin
	require "ruby_lsp/internal"
	require "ruby_lsp/literal/addon"
	true
rescue LoadError
	false
end

if ruby_lsp_available
	def document_symbols(source)
		dispatcher = Prism::Dispatcher.new
		response_builder = RubyLsp::ResponseBuilders::DocumentSymbol.new

		RubyLsp::Listeners::DocumentSymbol.new(response_builder, URI("file:///fake.rb"), dispatcher)
		RubyLsp::Literal::Addon.new.create_document_symbol_listener(response_builder, dispatcher)

		dispatcher.dispatch(Prism.parse(source).value)

		response_builder.response
	end

	test "lists props in the document outline" do
		symbols = document_symbols(<<~RUBY)
			prop :ignored, String

			module M
				class A
					prop :name, String
					prop? :tags, _Array(
						String
					)
					self.prop :age, Integer
					other.prop :ignored, String
				end
			end
		RUBY

		props = symbols.first.children.first.children

		assert_equal props.map(&:name), ["name", "tags", "age"]
		assert_equal props.map(&:detail), ["String", "_Array( String ) (optional)", "Integer"]
		assert_equal props.map(&:kind).uniq, [RubyLsp::Constant::SymbolKind::PROPERTY]
		assert_equal [props.first.selection_range.start.line, props.first.selection_range.start.character], [4, 7]
		assert_equal symbols.size, 1
	end

	test "lists props in props and coercion blocks but not other blocks" do
		symbols = document_symbols(<<~RUBY)
			module M
				A = Class.new(Literal::Data) { prop :hidden, String }

				class B
					props do
						prop :name, String
						prop :age, Integer do |value|
							prop :hidden, String
						end
					end

					included do
						prop :hidden, String
					end
				end
			end
		RUBY

		namespace = symbols.first

		assert_equal namespace.children.map(&:name), ["A", "B"]
		assert_equal namespace.children.last.children.map(&:name), ["name", "age"]
	end
end

if ruby_lsp_available && defined?(RubyIndexer::Enhancement)
	STDERR_CAPTURE_LOCK = Mutex.new

	def index_source(source)
		index = RubyIndexer::Index.new
		uri = URI::Generic.from_path(path: "/fake/#{SecureRandom.hex}.rb")
		captured = StringIO.new

		STDERR_CAPTURE_LOCK.synchronize do
			original_stderr = $stderr
			$stderr = captured

			begin
				index.index_single(uri, source)
			ensure
				$stderr = original_stderr
			end
		end

		assert_equal captured.string, ""

		index
	end

	test "indexes the instance variable for a prop" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String
			end
		RUBY

		entries = index["@name"]

		assert_equal entries.size, 1
		assert RubyIndexer::Entry::InstanceVariable === entries.first
		assert_equal entries.first.owner.name, "A"
		assert entries.first.comments.include?("String")
	end

	test "doesn't index a reader or writer by default" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String
			end
		RUBY

		assert_equal index["name"], nil
		assert_equal index["name="], nil
	end

	test "indexes a reader with its visibility" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, reader: :protected
			end
		RUBY

		entries = index["name"]

		assert_equal entries.size, 1
		assert RubyIndexer::Entry::Method === entries.first
		assert_equal entries.first.visibility, :protected
		assert_equal entries.first.signatures.first.parameters, []
	end

	test "indexes a writer with its visibility" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, writer: :public
			end
		RUBY

		entries = index["name="]

		assert_equal entries.size, 1
		assert_equal entries.first.visibility, :public
		assert_equal entries.first.signatures.first.parameters.map(&:name), [:value]
	end

	test "ignores a prop call without arguments" do
		index = index_source(<<~RUBY)
			class A
				prop
			end
		RUBY

		assert_equal index["@name"], nil
	end

	test "ignores keyword splats and string keys" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, **OPTIONS
				prop :age, Integer, "reader" => :public
				prop :email, String, **OPTIONS, reader: :public
			end
		RUBY

		assert_equal index["@name"].size, 1
		assert_equal index["@age"].size, 1
		assert_equal index["age"], nil
		assert_equal index["email"].first.visibility, :public
	end

	test "a keyword splat overrides options given before it" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, reader: :public, writer: :public, **OPTIONS
			end
		RUBY

		assert_equal index["@name"].size, 1
		assert_equal index["name"], nil
		assert_equal index["name="], nil
	end

	test "detects whether index entries take a configuration" do
		takes_configuration = Gem::Version.new(RubyLsp::VERSION) >= Gem::Version.new("0.26.5")

		assert_equal RubyLsp::Literal::IndexingEnhancement::ENTRIES_TAKE_CONFIGURATION, takes_configuration
	end

	test "ignores prop calls outside a namespace" do
		index = index_source(<<~RUBY)
			prop :name, String
		RUBY

		assert_equal index["@name"], nil
	end

	test "indexes an optional prop" do
		index = index_source(<<~RUBY)
			class A
				prop? :name, String, reader: :public
			end
		RUBY

		assert_equal index["@name"].size, 1
		assert index["name"].first.comments.include?("**Type:** (optional)")
	end

	test "indexes a predicate with its visibility" do
		index = index_source(<<~RUBY)
			class A
				prop :admin, _Boolean, predicate: :private
			end
		RUBY

		assert_equal index["admin?"].first.visibility, :private
		assert_equal index["admin"], nil
	end

	test "documents readers and writers with comments, description and type" do
		index = index_source(<<~RUBY)
			class A
				# The full name.
				prop :name, String, reader: :public, writer: :public, description: "As printed."
			end
		RUBY

		expected = "The full name.\n\nAs printed.\n\n**Type:**\n```ruby\nString\n```"

		assert_equal index["@name"].first.comments, expected
		assert_equal index["name"].first.comments, expected
		assert_equal index["name="].first.comments, expected
	end

	test "indexes default readers and writers for direct subclasses of Literal::Struct" do
		index = index_source(<<~RUBY)
			class A < Literal::Struct
				prop :name, String
				prop :age, Integer, reader: false, writer: :private
			end
		RUBY

		assert_equal index["name"].first.visibility, :public
		assert_equal index["name="].first.visibility, :public
		assert_equal index["age"], nil
		assert_equal index["age="].first.visibility, :private
	end

	test "indexes default readers for direct subclasses of Literal::Data and Literal::Enum" do
		index = index_source(<<~RUBY)
			class A < ::Literal::Data
				prop :name, String
			end

			class B < Literal::Enum
				prop :hex, String
			end
		RUBY

		assert_equal index["name"].first.visibility, :public
		assert_equal index["name="], nil
		assert_equal index["hex"].first.visibility, :public
	end

	test "doesn't index default readers when a keyword splat may override them" do
		index = index_source(<<~RUBY)
			class A < Literal::Struct
				prop :name, String, **OPTIONS
				prop :age, Integer, **OPTIONS, reader: :public
			end
		RUBY

		assert_equal index["name"], nil
		assert_equal index["name="], nil
		assert_equal index["age"].first.visibility, :public
		assert_equal index["age="], nil
	end

	test "doesn't index default readers when a computed key may override them" do
		index = index_source(<<~RUBY)
			class A < Literal::Struct
				prop :name, String, READER => false
				prop :age, Integer, READER => false, reader: :private
			end
		RUBY

		assert_equal index["name"], nil
		assert_equal index["age"].first.visibility, :private
	end

	test "indexes props in props and coercion blocks but not other blocks" do
		index = index_source(<<~RUBY)
			module M
				A = Class.new(Literal::Data) { prop :hidden, String }

				class B
					props do
						prop :name, String
						prop :age, Integer do |value|
							prop :hidden, String
						end
					end

					included do
						prop :hidden, String

						class C
							prop :email, String
						end
					end
				end
			end
		RUBY

		assert_equal index["@hidden"], nil
		assert_equal index["@name"].first.owner.name, "M::B"
		assert_equal index["@age"].first.owner.name, "M::B"
		assert_equal index["@email"].first.owner.name, "M::B::C"
	end
end
