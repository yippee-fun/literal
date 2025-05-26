# frozen_string_literal: true

module Literal::Rails
	module ActiveRecordRelationPatch
		def Relation(model)
			RelationType.new(model)
		end
	end
end
