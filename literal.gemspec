# frozen_string_literal: true

require_relative "lib/literal/version"

Gem::Specification.new do |spec|
	spec.name = "literal"
	spec.version = Literal::VERSION
	spec.authors = ["Joel Drapper"]
	spec.email = ["joel@drapper.me"]

	spec.summary = "Enums, properties, generics, structured objects and runtime type checking."
	spec.description = "Enums, properties, generics, structured objects and runtime type checking."
	spec.homepage = "https://literal.fun"
	spec.license = "MIT"
	spec.required_ruby_version = ">= 3.1"

	spec.metadata["homepage_uri"] = spec.homepage
	spec.metadata["source_code_uri"] = "https://github.com/joeldrapper/literal"
	spec.metadata["changelog_uri"] = "https://github.com/joeldrapper/literal/releases"
	spec.metadata["funding_uri"] = "https://github.com/sponsors/joeldrapper"

	spec.files = Dir[
		"README.md",
		"LICENSE.txt",
		"lib/**/*.rb"
	]

	spec.require_paths = ["lib"]

	spec.add_runtime_dependency "zeitwerk"

	spec.metadata["rubygems_mfa_required"] = "true"
end
