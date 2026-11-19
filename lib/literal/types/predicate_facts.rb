# frozen_string_literal: true

# Facts about predicate methods that subtype checking may rely on, keyed by
# method name. Each entry maps a receiver bound to the knowledge that holds
# under it — the same predicate can mean different things on different
# receivers, and a fact only applies when the receiver is provably bounded
# by its key (matched with subtype?, not hash lookup). Ruby's built-in
# numerics are trusted to honor these contracts, while any other object may
# redefine the same method to return anything.
#
# boolean: the method returns exactly true or false.
# entails: a truthy result proves membership of this type.
Literal::Types::PredicateFacts = {
	finite?: {
		Numeric => { boolean: true }.freeze,
	}.freeze,
	integer?: {
		Numeric => { boolean: true, entails: Integer }.freeze,
	}.freeze,
}.freeze
