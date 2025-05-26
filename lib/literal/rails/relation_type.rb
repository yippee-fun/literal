# frozen_string_literal: true

module Literal::Rails
	class RelationType
		def initialize(model_class)
			unless Class === model_class && model_class < ActiveRecord::Base
				raise Literal::TypeError.new(
						context: Literal::TypeError::Context.new(
							expected: ActiveRecord::Base, actual: model_class
						)
					)
			end

			@model_class = model_class
		end

		def inspect = "ActiveRecord::Relation(#{@model_class.name})"

		def ===(value)
			case value
				when ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy, ActiveRecord::AssociationRelation
					@model_class == value.model || value.model < @model_class
				else
					false
			end
		end
	end
end
