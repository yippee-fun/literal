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
	def index_source(source)
		index = RubyIndexer::Index.new
		uri = URI::Generic.from_path(path: "/fake/#{SecureRandom.hex}.rb")

		errors = []
		original_stderr = $stderr
		$stderr = StringIO.new

		begin
			index.index_single(uri, source)
		ensure
			errors = $stderr.string
			$stderr = original_stderr
		end

		assert_equal "", errors

		index
	end

	test "indexes the instance variable for a prop" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String
			end
		RUBY

		entries = index["@name"]

		assert_equal 1, entries.size
		assert RubyIndexer::Entry::InstanceVariable === entries.first
		assert_equal "A", entries.first.owner.name
		assert entries.first.comments.include?("String")
	end

	test "doesn't index a reader or writer by default" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String
			end
		RUBY

		assert_equal nil, index["name"]
		assert_equal nil, index["name="]
	end

	test "indexes a reader with its visibility" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, reader: :protected
			end
		RUBY

		entries = index["name"]

		assert_equal 1, entries.size
		assert RubyIndexer::Entry::Method === entries.first
		assert_equal :protected, entries.first.visibility
		assert_equal [], entries.first.signatures.first.parameters
	end

	test "indexes a writer with its visibility" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, writer: :public
			end
		RUBY

		entries = index["name="]

		assert_equal 1, entries.size
		assert_equal :public, entries.first.visibility
		assert_equal [:value], entries.first.signatures.first.parameters.map(&:name)
	end

	test "ignores a prop call without arguments" do
		index = index_source(<<~RUBY)
			class A
				prop
			end
		RUBY

		assert_equal nil, index["@name"]
	end

	test "ignores keyword splats and string keys" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, **OPTIONS
				prop :age, Integer, "reader" => :public
				prop :email, String, **OPTIONS, reader: :public
			end
		RUBY

		assert_equal 1, index["@name"].size
		assert_equal 1, index["@age"].size
		assert_equal nil, index["age"]
		assert_equal :public, index["email"].first.visibility
	end

	test "a keyword splat overrides options given before it" do
		index = index_source(<<~RUBY)
			class A
				prop :name, String, reader: :public, writer: :public, **OPTIONS
			end
		RUBY

		assert_equal 1, index["@name"].size
		assert_equal nil, index["name"]
		assert_equal nil, index["name="]
	end

	test "detects whether index entries take a configuration" do
		takes_configuration = Gem::Version.new(RubyLsp::VERSION) >= Gem::Version.new("0.26.5")

		assert_equal takes_configuration, RubyLsp::Literal::IndexingEnhancement::ENTRIES_TAKE_CONFIGURATION
	end

	test "ignores prop calls outside a namespace" do
		index = index_source(<<~RUBY)
			prop :name, String
		RUBY

		assert_equal nil, index["@name"]
	end
end
