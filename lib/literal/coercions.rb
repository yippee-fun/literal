# frozen_string_literal: true

# Named coercions for property definitions, passed as the prop’s block:
#
#   prop :name, String, &Immutable
#   prop :bio, _Nilable(String), &(NilIfEmpty >> Literal::Coercions.Truncated(255))
#
# These are plain procs, so they compose with `Proc#>>`.
module Literal::Coercions
	# Shallow: freezes a copy, so the caller’s object is never mutated.
	# References held by the value (array elements, hash values) stay mutable.
	Immutable = proc { |it| it.frozen? ? it : it.dup.freeze }

	# Deep: makes the value Ractor-shareable, freezing the entire object graph.
	# Works on a deep copy, so the caller’s object is never mutated. Raises
	# Ractor::IsolationError for values that cannot be made shareable (IO,
	# Thread, procs capturing mutable state).
	DeepImmutable = proc do |it|
		Ractor.shareable?(it) ? it : Ractor.make_shareable(it, copy: true)
	end

	# Converts empty values ("", [], {}) to nil, for optional properties where
	# empty input means absent. Everything else passes through untouched.
	NilIfEmpty = proc { |it| (it.respond_to?(:empty?) && it.empty?) ? nil : it }
end
