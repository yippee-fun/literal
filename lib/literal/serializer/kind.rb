# frozen_string_literal: true

# Mixed into the companion kind types that serializers expose. A kind is a
# supertype of every type its serializer can handle: `matches?` is the shallow,
# non-recursive structural check used for dispatch, while `>=` combines it with
# the context's serializability walk so that `context.kind === type` remains a
# complete answer, including child types and recursion.
module Literal::Serializer::Kind
	include Literal::Type

	def >=(other, context: nil)
		matches?(other) && @context.serializable_type?(other)
	end
end
