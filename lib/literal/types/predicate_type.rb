# frozen_string_literal: true

class Literal::Types::PredicateType
	include Literal::Type

	RECURSION_REJECT = :reject
	RECURSION_ACCEPT = :accept
	RECURSION_POLICIES = [RECURSION_REJECT, RECURSION_ACCEPT].freeze
	THREAD_KEY = :literal_predicate_state

	def initialize(message:, block:, recursion: RECURSION_REJECT)
		unless RECURSION_POLICIES.include?(recursion)
			raise ArgumentError, "Unknown recursion policy #{recursion.inspect}"
		end

		@message = message
		@block = block
		@recursion = recursion

		freeze
	end

	def inspect
		%(_Predicate("#{@message}"))
	end

	def ===(other)
		state = (Thread.current[THREAD_KEY] ||= {})
		key = [object_id, other.object_id]

		return @recursion == RECURSION_ACCEPT if state[key]

		state[key] = true
		@block === other
	ensure
		state&.delete(key)
		Thread.current[THREAD_KEY] = nil if state&.empty?
	end

	freeze
end
