# frozen_string_literal: true

module Literal::Type
	# A type that overrides >= or <= reaches these only through super, which
	# answers with the rule from before they went through subtype?.
	def >=(other, context: nil)
		if literal_overrides?(:>=)
			self == other
		else
			Literal.subtype?(other, self, context:)
		end
	end

	def <=(other, context: nil)
		if literal_overrides?(:<=) && !(Literal::Type === other)
			literal_bounded_by?(other, context:)
		else
			Literal.subtype?(self, other, context:)
		end
	end

	# This type's own rule for Literal.subtype?, which has already taken apart
	# unions, nilables, tagged unions, results and deferred types on the left
	# and checked equality. Answers with a type's own >= while it still
	# overrides that rather than this.
	def literal_supertype_of?(other, context:)
		literal_overrides?(:>=) && self.>=(other, context:)
	end

	# This type's own rule for Literal.subtype?, asked after the supertype's
	# rule fails. Against a module or range it defaults to the upper bound
	# being a subtype, or a type's own <= while it still overrides that rather
	# than this.
	def literal_subtype_of?(other, context:)
		if Literal::Type === other
			false
		elsif literal_overrides?(:<=)
			self.<=(other, context:)
		else
			literal_bounded_by?(other, context:)
		end
	end

	# A type admitting every value this one does, which answers whether this
	# type is a subtype of a module. nil when there is no useful bound.
	def literal_upper_bound
		nil
	end

	def literal_child_types
		enum_for(__method__) unless block_given?
	end

	def name
		Literal.const_name(self)
	end

	private def literal_overrides?(operator)
		!Literal::Type.equal?(Literal::METHOD.bind_call(self, operator).owner)
	end

	private def literal_bounded_by?(other, context:)
		bound = literal_upper_bound
		!bound.nil? && Literal.subtype?(bound, other, context:)
	end

	private def literal_hash(*components)
		components.hash
	rescue NoMethodError
		Literal.member_hash(components)
	end
end
