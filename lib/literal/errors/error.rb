# frozen_string_literal: true

module Literal::Error
	INTERNALS = File.expand_path("../..", __dir__).freeze
	private_constant :INTERNALS

	# Starts a backtrace where the caller called into Literal. Trimmed by path
	# rather than by count, because the paths that raise are different depths
	# and engines report different frames: only CRuby reports `new` or a
	# `rescue in` frame, and TruffleRuby puts its own <internal:core> frames
	# between Literal's. The codegen's eval frames carry properties.rb as their
	# path, so they go too.
	def self.trim(frames)
		trimmed = frames.drop_while do |location|
			location.path.include?(INTERNALS) || location.path.start_with?("<internal:")
		end

		(trimmed.empty? ? frames : trimmed).map(&:to_s)
	end
end
