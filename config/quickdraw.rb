# frozen_string_literal: true

require "active_record/railtie"
require "literal"
require "securerandom"
require "set"

module Fixtures
	Objects = Set[
		SecureRandom.hex,
		SecureRandom.hex.freeze,
		0,
		0.0,
		[],
		[].freeze,
		{},
		{}.freeze,
		true,
		String,
		Integer,
		Float,
		Array,
		SecureRandom,
		false
	].freeze
end

Literal::Loader.eager_load

if ENV["COVERAGE"] == "true"
	require "simplecov"

	SimpleCov.start do
		command_name "quickdraw"
		enable_coverage_for_eval
		enable_for_subprocesses true
		enable_coverage :branch

		add_group "Types", "lib/literal/types"
		add_group "Enums", "lib/literal/enum.rb"
		add_group "Properties", "lib/literal/properties.rb"
	end
end

class Quickdraw::Test
	def assert_subtype(subtype, supertype)
		assert Literal.subtype?(subtype, supertype) do
			"Expected #{subtype.inspect} to be a subtype of #{supertype.inspect}."
		end
	end

	def refute_subtype(subtype, supertype)
		refute Literal.subtype?(subtype, supertype) do
			"Expected #{subtype.inspect} not to be a subtype of #{supertype.inspect}."
		end
	end
end
