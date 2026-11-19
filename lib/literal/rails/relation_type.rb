# frozen_string_literal: true

module Literal::Rails
	class RelationType
		include Literal::Type

		def initialize(model_class)
			@model_class = model_class
		end

		attr_reader :model_class

		def inspect = "ActiveRecord::Relation(#{@model_class.name})"

		def ==(other)
			RelationType === other && @model_class == other.model_class
		end

		def ===(value)
			case value
			when ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy, ActiveRecord::AssociationRelation
				@model_class == value.model || value.model < @model_class
			else
				false
			end
		end

		def >=(other, context: nil)
			case other
			when RelationType
				other_model = other.model_class
				@model_class == other_model || other_model < @model_class
			else
				false
			end
		end

		def <=(other, context: nil)
			case other
			when Module
				# Every value we match is an ActiveRecord::Relation (collection
				# proxies and association relations are subclasses), so we are a
				# subtype of anything that class is — including Enumerable.
				other >= ActiveRecord::Relation
			when Literal::Type
				other.>=(self, context:)
			else
				false
			end
		end

		def literal_child_types
			return enum_for(__method__) unless block_given?

			yield @model_class
		end
	end
end
